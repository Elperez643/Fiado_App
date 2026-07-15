using System.Security.Claims;
using FiadoApp.Api.Data;
using FiadoApp.Api.DTOs;
using FiadoApp.Api.Entities;
using Microsoft.EntityFrameworkCore;

namespace FiadoApp.Api.Services;

public sealed class CreditCycleService(FiadoDbContext dbContext) : ICreditCycleService
{
    public async Task<IReadOnlyList<CreditCycleResponse>> GetByClientAsync(ClaimsPrincipal user, Guid clientId)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "ciclos de credito");
        await EnsureClientForBusinessAsync(businessId, clientId);
        return await BaseQuery(businessId)
            .Where(x => x.ClientId == clientId)
            .OrderByDescending(x => x.StartDate)
            .Select(x => MapCycle(x))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<CreditCycleResponse>> GetAccountsReceivableAsync(ClaimsPrincipal user)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "ciclos de credito");
        return await BaseQuery(businessId)
            .Where(x => x.PendingBalance > 0)
            .OrderBy(x => x.DueDate30)
            .Select(x => MapCycle(x))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<CreditCycleResponse>> GetOverdue45Async(ClaimsPrincipal user)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "ciclos de credito");
        return await BaseQuery(businessId)
            .Where(x => x.Status == "mora_45" || x.DueDate45 <= DateTime.UtcNow && x.PendingBalance > 0)
            .OrderBy(x => x.DueDate45)
            .Select(x => MapCycle(x))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<CreditCycleResponse>> GetBlocked60Async(ClaimsPrincipal user)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "ciclos de credito");
        return await BaseQuery(businessId)
            .Where(x => x.IsBlocked || x.Status == "bloqueado_60")
            .OrderBy(x => x.Block60Date)
            .Select(x => MapCycle(x))
            .ToListAsync();
    }

    public async Task<CreditCycleSyncPushResponse> PushSyncAsync(ClaimsPrincipal user, CreditCycleSyncPushRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "ciclos de credito");
        var response = new CreditCycleSyncPushResponse { ServerTime = DateTime.UtcNow };
        foreach (var item in request.CreditCycles)
        {
            response.Results.Add(await TryApplyPushAsync(businessId, item));
        }
        foreach (var item in request.CreditReminders)
        {
            response.CreditReminderResults.Add(await TryApplyReminderPushAsync(businessId, item));
        }
        foreach (var item in request.CreditExceptions)
        {
            response.CreditExceptionResults.Add(await TryApplyExceptionPushAsync(businessId, item));
        }
        return response;
    }

    public async Task<CreditCycleSyncPullResponse> PullSyncAsync(ClaimsPrincipal user, CreditCycleSyncPullRequest request)
    {
        var businessId = FinancialSyncMapper.GetBusinessIdForBusinessUser(user, "ciclos de credito");
        var cyclesQuery = BaseQuery(businessId);
        var remindersQuery = dbContext.CreditReminders.AsNoTracking().Where(x => x.BusinessId == businessId);
        var exceptionsQuery = dbContext.CreditExceptions.AsNoTracking().Where(x => x.BusinessId == businessId);

        if (request.LastSyncAt is not null)
        {
            cyclesQuery = cyclesQuery.Where(x => x.UpdatedAt > request.LastSyncAt);
            remindersQuery = remindersQuery.Where(x => x.UpdatedAt > request.LastSyncAt);
            exceptionsQuery = exceptionsQuery.Where(x => x.UpdatedAt > request.LastSyncAt);
        }

        return new CreditCycleSyncPullResponse
        {
            ServerTime = DateTime.UtcNow,
            CreditCycles = await cyclesQuery.OrderBy(x => x.UpdatedAt).Select(x => MapCycle(x)).ToListAsync(),
            CreditReminders = await remindersQuery.OrderBy(x => x.UpdatedAt).Select(x => MapReminder(x)).ToListAsync(),
            CreditExceptions = await exceptionsQuery.OrderBy(x => x.UpdatedAt).Select(x => MapException(x)).ToListAsync()
        };
    }

    private IQueryable<CreditCycle> BaseQuery(Guid businessId)
    {
        return dbContext.CreditCycles.AsNoTracking().Where(x => x.BusinessId == businessId);
    }

    private async Task<FinancialSyncPushItemResponse> TryApplyPushAsync(Guid businessId, FinancialSyncPushItemRequest item)
    {
        try
        {
            var cycle = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertFromPushAsync(businessId, item, true),
                "update" => await UpsertFromPushAsync(businessId, item, true),
                "delete" => await UpsertFromPushAsync(businessId, item, false),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };

            return new FinancialSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = cycle.Id,
                Status = item.Operation == "create" ? "created" : "updated",
                ServerUpdatedAt = cycle.UpdatedAt
            };
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
        {
            return new FinancialSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = item.ServerId,
                Status = "failed",
                Error = ex.Message
            };
        }
    }

    private async Task<CreditCycle> UpsertFromPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool allowCreate)
    {
        var cycle = await FindForPushAsync(businessId, item, throwIfMissing: !allowCreate);
        var now = DateTime.UtcNow;
        var clientId = FinancialSyncMapper.GuidValue(item.Payload, "clientId", "client_id", "cliente_id") ??
            throw new InvalidOperationException("Ciclo de credito requiere clientId.");
        await EnsureClientForBusinessAsync(businessId, clientId);

        cycle ??= new CreditCycle
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt
        };

        cycle.ClientId = clientId;
        cycle.StartDate = FinancialSyncMapper.DateValue(item.Payload, now, "startDate", "start_date", "fecha_inicio");
        cycle.DueDate30 = FinancialSyncMapper.DateValue(item.Payload, cycle.StartDate.AddDays(30), "dueDate30", "due_date_30", "fecha_limite_30");
        cycle.DueDate45 = FinancialSyncMapper.DateValue(item.Payload, cycle.StartDate.AddDays(45), "dueDate45", "due_date_45", "fecha_limite_45");
        cycle.Block60Date = FinancialSyncMapper.DateValue(item.Payload, cycle.StartDate.AddDays(60), "blockDate60", "block_date_60", "fecha_bloqueo_60");
        cycle.Status = FinancialSyncMapper.Text(item.Payload, "status", "estado") ?? "activo";
        cycle.TotalAmount = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["totalAmount", "total_amount", "monto_total"]);
        cycle.PaidAmount = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["paidAmount", "paid_amount", "monto_pagado"]);
        cycle.PendingBalance = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["pendingBalance", "pending_balance", "saldo_pendiente"]);
        cycle.IsBlocked = FinancialSyncMapper.BoolValue(item.Payload, false, "isBlocked", "is_blocked", "bloqueado");
        cycle.SettledAt = FinancialSyncMapper.DateValue(item.Payload, default, "settledAt", "settled_at", "fecha_saldado");
        if (cycle.SettledAt == default)
        {
            cycle.SettledAt = null;
        }
        cycle.UpdatedAt = now;
        cycle.LastSyncedAt = now;
        cycle.SyncStatus = "synced";

        if (cycle.Id == default || dbContext.Entry(cycle).State == EntityState.Detached)
        {
            dbContext.CreditCycles.Add(cycle);
        }

        await dbContext.SaveChangesAsync();
        return cycle;
    }

    private async Task<CreditCycle?> FindForPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool throwIfMissing)
    {
        var query = dbContext.CreditCycles.Where(x => x.BusinessId == businessId);
        var cycle = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : null;
        cycle ??= await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);
        if (cycle is null && throwIfMissing)
        {
            throw new KeyNotFoundException("Ciclo de credito no encontrado para este negocio.");
        }
        return cycle;
    }

    private async Task<FinancialSyncPushItemResponse> TryApplyReminderPushAsync(Guid businessId, FinancialSyncPushItemRequest item)
    {
        try
        {
            var reminder = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertReminderFromPushAsync(businessId, item, true),
                "update" => await UpsertReminderFromPushAsync(businessId, item, allowCreate: item.ServerId is null),
                "delete" => await UpsertReminderFromPushAsync(businessId, item, false),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };

            return new FinancialSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = reminder.Id,
                Status = item.Operation == "create" ? "created" : "updated",
                ServerUpdatedAt = reminder.UpdatedAt
            };
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
        {
            return new FinancialSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = item.ServerId,
                Status = "failed",
                Error = ex.Message
            };
        }
    }

    private async Task<FinancialSyncPushItemResponse> TryApplyExceptionPushAsync(Guid businessId, FinancialSyncPushItemRequest item)
    {
        try
        {
            var exception = item.Operation.Trim().ToLowerInvariant() switch
            {
                "create" => await UpsertExceptionFromPushAsync(businessId, item, true),
                "update" => await UpsertExceptionFromPushAsync(businessId, item, allowCreate: item.ServerId is null),
                "delete" => await UpsertExceptionFromPushAsync(businessId, item, false),
                _ => throw new InvalidOperationException($"Operacion de sync no soportada: {item.Operation}")
            };

            return new FinancialSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = exception.Id,
                Status = item.Operation == "create" ? "created" : "updated",
                ServerUpdatedAt = exception.UpdatedAt
            };
        }
        catch (Exception ex) when (ex is InvalidOperationException or KeyNotFoundException)
        {
            return new FinancialSyncPushItemResponse
            {
                LocalId = item.LocalId,
                ServerId = item.ServerId,
                Status = "failed",
                Error = ex.Message
            };
        }
    }

    private async Task<CreditReminder> UpsertReminderFromPushAsync(
        Guid businessId,
        FinancialSyncPushItemRequest item,
        bool allowCreate)
    {
        var reminder = await FindReminderForPushAsync(businessId, item, throwIfMissing: !allowCreate);
        var now = DateTime.UtcNow;
        var cycleId = FinancialSyncMapper.GuidValue(item.Payload, "creditCycleId", "credit_cycle_id", "ciclo_id") ??
            throw new InvalidOperationException("Recordatorio de credito requiere creditCycleId.");
        var clientId = FinancialSyncMapper.GuidValue(item.Payload, "clientId", "client_id", "cliente_id") ??
            throw new InvalidOperationException("Recordatorio de credito requiere clientId.");
        await EnsureCycleForBusinessAsync(businessId, cycleId);
        await EnsureClientForBusinessAsync(businessId, clientId);

        reminder ??= new CreditReminder
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt
        };

        reminder.CreditCycleId = cycleId;
        reminder.ClientId = clientId;
        reminder.Type = FinancialSyncMapper.Text(item.Payload, "type", "tipo") ?? "toque_manual";
        reminder.Message = FinancialSyncMapper.Text(item.Payload, "message", "mensaje") ?? string.Empty;
        reminder.Channel = FinancialSyncMapper.Text(item.Payload, "channel", "canal") ?? "interno";
        reminder.Status = FinancialSyncMapper.Text(item.Payload, "status", "estado") ?? "pendiente";
        reminder.GeneratedAt = FinancialSyncMapper.DateValue(item.Payload, now, "generatedAt", "generated_at", "fecha_generado");
        reminder.SentAt = NullableDateValue(item.Payload, "sentAt", "sent_at", "fecha_enviado");
        reminder.UpdatedAt = now;
        reminder.SyncStatus = "synced";

        if (reminder.Id == default || dbContext.Entry(reminder).State == EntityState.Detached)
        {
            dbContext.CreditReminders.Add(reminder);
        }

        await dbContext.SaveChangesAsync();
        return reminder;
    }

    private async Task<CreditException> UpsertExceptionFromPushAsync(
        Guid businessId,
        FinancialSyncPushItemRequest item,
        bool allowCreate)
    {
        var exception = await FindExceptionForPushAsync(businessId, item, throwIfMissing: !allowCreate);
        var now = DateTime.UtcNow;
        var cycleId = FinancialSyncMapper.GuidValue(item.Payload, "creditCycleId", "credit_cycle_id", "ciclo_id") ??
            throw new InvalidOperationException("Excepcion de credito requiere creditCycleId.");
        var clientId = FinancialSyncMapper.GuidValue(item.Payload, "clientId", "client_id", "cliente_id") ??
            throw new InvalidOperationException("Excepcion de credito requiere clientId.");
        var movementId = FinancialSyncMapper.GuidValue(item.Payload, "movementId", "movement_id", "movimiento_id");
        await EnsureCycleForBusinessAsync(businessId, cycleId);
        await EnsureClientForBusinessAsync(businessId, clientId);
        if (movementId is not null)
        {
            await EnsureMovementForBusinessAsync(businessId, movementId.Value);
        }

        exception ??= new CreditException
        {
            BusinessId = businessId,
            LocalId = item.LocalId,
            CreatedAt = item.UpdatedAt == default ? now : item.UpdatedAt
        };

        exception.CreditCycleId = cycleId;
        exception.ClientId = clientId;
        exception.MovementId = movementId;
        exception.Reason = FinancialSyncMapper.Text(item.Payload, "reason", "motivo");
        exception.Amount = FinancialSyncMapper.DecimalValue(item.Payload, keys: ["amount", "monto_fiado"]);
        exception.Date = FinancialSyncMapper.DateValue(item.Payload, now, "date", "fecha");
        exception.UpdatedAt = now;
        exception.LastSyncedAt = now;
        exception.SyncStatus = "synced";

        if (exception.Id == default || dbContext.Entry(exception).State == EntityState.Detached)
        {
            dbContext.CreditExceptions.Add(exception);
        }

        await dbContext.SaveChangesAsync();
        return exception;
    }

    private async Task<CreditReminder?> FindReminderForPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool throwIfMissing)
    {
        var query = dbContext.CreditReminders.Where(x => x.BusinessId == businessId);
        var reminder = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : null;
        reminder ??= await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);
        if (reminder is null && throwIfMissing)
        {
            throw new KeyNotFoundException("Recordatorio de credito no encontrado para este negocio.");
        }
        return reminder;
    }

    private async Task<CreditException?> FindExceptionForPushAsync(Guid businessId, FinancialSyncPushItemRequest item, bool throwIfMissing)
    {
        var query = dbContext.CreditExceptions.Where(x => x.BusinessId == businessId);
        var exception = item.ServerId is not null
            ? await query.FirstOrDefaultAsync(x => x.Id == item.ServerId)
            : null;
        exception ??= await query.FirstOrDefaultAsync(x => x.LocalId == item.LocalId);
        if (exception is null && throwIfMissing)
        {
            throw new KeyNotFoundException("Excepcion de credito no encontrada para este negocio.");
        }
        return exception;
    }

    private async Task<Client> EnsureClientForBusinessAsync(Guid businessId, Guid clientId)
    {
        var client = await dbContext.Clients.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == clientId);
        return client ?? throw new KeyNotFoundException("Cliente no encontrado para este negocio.");
    }

    private async Task<CreditCycle> EnsureCycleForBusinessAsync(Guid businessId, Guid cycleId)
    {
        var cycle = await dbContext.CreditCycles.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == cycleId);
        return cycle ?? throw new KeyNotFoundException("Ciclo de credito no encontrado para este negocio.");
    }

    private async Task<Movement> EnsureMovementForBusinessAsync(Guid businessId, Guid movementId)
    {
        var movement = await dbContext.Movements.FirstOrDefaultAsync(x => x.BusinessId == businessId && x.Id == movementId);
        return movement ?? throw new KeyNotFoundException("Movimiento no encontrado para este negocio.");
    }

    private static DateTime? NullableDateValue(IReadOnlyDictionary<string, System.Text.Json.JsonElement> payload, params string[] keys)
    {
        var value = FinancialSyncMapper.DateValue(payload, default, keys);
        return value == default ? null : value;
    }

    private static CreditCycleResponse MapCycle(CreditCycle cycle)
    {
        return new CreditCycleResponse
        {
            Id = cycle.Id,
            LocalId = cycle.LocalId,
            RemoteId = cycle.RemoteId,
            BusinessId = cycle.BusinessId,
            ClientId = cycle.ClientId,
            StartDate = cycle.StartDate,
            DueDate30 = cycle.DueDate30,
            DueDate45 = cycle.DueDate45,
            BlockDate60 = cycle.Block60Date,
            Status = cycle.Status,
            TotalAmount = cycle.TotalAmount,
            PaidAmount = cycle.PaidAmount,
            PendingBalance = cycle.PendingBalance,
            IsBlocked = cycle.IsBlocked,
            SettledAt = cycle.SettledAt,
            CreatedAt = cycle.CreatedAt,
            UpdatedAt = cycle.UpdatedAt,
            LastSyncedAt = cycle.LastSyncedAt
        };
    }

    private static CreditReminderResponse MapReminder(CreditReminder reminder)
    {
        return new CreditReminderResponse
        {
            Id = reminder.Id,
            LocalId = reminder.LocalId,
            BusinessId = reminder.BusinessId,
            CreditCycleId = reminder.CreditCycleId,
            ClientId = reminder.ClientId,
            Type = reminder.Type,
            Message = reminder.Message,
            Channel = reminder.Channel,
            Status = reminder.Status,
            GeneratedAt = reminder.GeneratedAt,
            SentAt = reminder.SentAt,
            CreatedAt = reminder.CreatedAt,
            UpdatedAt = reminder.UpdatedAt
        };
    }

    private static CreditExceptionResponse MapException(CreditException exception)
    {
        return new CreditExceptionResponse
        {
            Id = exception.Id,
            LocalId = exception.LocalId,
            RemoteId = exception.RemoteId,
            BusinessId = exception.BusinessId,
            CreditCycleId = exception.CreditCycleId,
            ClientId = exception.ClientId,
            UserId = exception.UserId,
            Reason = exception.Reason,
            Amount = exception.Amount,
            MovementId = exception.MovementId,
            Date = exception.Date,
            CreatedAt = exception.CreatedAt,
            UpdatedAt = exception.UpdatedAt,
            LastSyncedAt = exception.LastSyncedAt
        };
    }
}
