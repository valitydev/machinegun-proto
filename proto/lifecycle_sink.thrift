namespace erlang mg_lifesink
namespace java dev.vality.machinegun.lifesink
namespace elixir MachinegunProto.LifeSink

/**
 * Определения структур для поддержания взаимодействия с потребителями
 * событий, порождённых жизненными циклами сущностей machinegun.
 */

// Loosely inspired by valitydev/machinegun-core/include/pulse.hrl

include "base.thrift"
include "state_processing.thrift"

typedef state_processing.MachineStatus MachineStatus;

struct LifecycleEvent {
    1: required base.Namespace     machine_ns     /* Идентификатор пространства имён, породившего событие */
    2: required base.ID            machine_id     /* Идентификатор машины, породившей событие */
    3: required base.Timestamp     created_at     /* Время происхождения события */
    4: required LifecycleEventData data           /* Данные события */
}

union LifecycleEventData {
    1: MachineLifecycleEvent    machine
    // If we want to achieve the goal of mg replication, we can extend this for other things later, e.g.:
    // 2: TimerLifecycleEvent    timer
    // ... etc.
}

union MachineLifecycleEvent {
    1: MachineLifecycleCreatedEvent       created
    2: MachineLifecycleStatusChangedEvent status_changed
    3: MachineLifecycleRemovedEvent       removed
}

struct MachineLifecycleCreatedEvent {}
struct MachineLifecycleStatusChangedEvent {
   1: required MachineStatus new_status
}
struct MachineLifecycleRemovedEvent {}
