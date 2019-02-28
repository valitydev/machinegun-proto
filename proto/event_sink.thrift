namespace erlang mg_evsink
namespace java com.rbkmoney.machinegun.eventsink

/**
 * Определения структур для поддержания взаимодействия с потребителями
 * событий, порождённых процессором.
 */

include "base.thrift"
include "msgpack.thrift"


/**
 * Сообщение о неком изменении
 */
union SinkEvent {
    1: MachineEvent   event
}

/**
 * Сообщение о том, что один из автоматов породил новое событие
 */
struct MachineEvent {
    1: required base.Namespace  source_ns      /* Идентификатор пространства имён, породившего событие */
    2: required base.ID         source_id      /* Идентификатор объекта, породившего событие */
    /**
     * Идентификатор события.
     * Монотонно без пропусков возрастающее целочисленное значение, уникальное в пределах `source_id`.
     * Задает порядок порождения событий в пределах одного объекта.
     */
    3: required base.EventID    event_id
    4: required base.Timestamp  created_at     /* Время происхождения события */
    5: optional i32             format_version /* Версия представления данных */
    6: required msgpack.Value   data           /* Исходное событие */
}
