namespace erlang mg_stateproc
namespace java dev.vality.machinegun.stateproc

/**
 * Определения структур и сервисов для поддержания взаимодействия со
 * state processor – абстракции, реализующей шаг обработки (другими словами,
 * один переход состояния) ограниченного конечного автомата со сложным
 * состоянием, которое выражается при помощи истории как набора событий,
 * порождённых процессором.
 */

include "base.thrift"
include "msgpack.thrift"

exception EventNotFound {}
exception MachineNotFound {}
exception NamespaceNotFound {}
exception MachineAlreadyExists {}
exception MachineFailed {}
exception MachineAlreadyWorking {}

struct Content {
    /** Версия представления данных */
    1: optional i32           format_version
    2: required msgpack.Value data
}

typedef Content EventBody
typedef list<EventBody> EventBodies

typedef Content AuxState

typedef msgpack.Value Args

/**
 * Произвольное событие, продукт перехода в новое состояние.
 */
struct Event {
    /**
     * Идентификатор события.
     * Монотонно возрастающее целочисленное значение, таким образом на множестве
     * событий задаётся отношение полного порядка (total order).
     */
    1: required base.EventID    id
    /** Время происхождения события */
    2: required base.Timestamp  created_at

    // Inlined from `Content`

    /** Версия представления данных */
    5: optional i32 format_version
    /** Описание события */
    4: required msgpack.Value data
}

/**
 * История — упорядоченный набор эвентов отражающая состояние машины для некоторого диапазона истории.
 * Например, есть машина последний эвент у которой 11.
 * Допустим, известна первая версия (эвент с номером 1, т.е. дельта между версиями 0 и 1)
 * Нужно получить дельту изменений до 10й версии (т.е. эвенты со 2-го до 10-го).
 * В таком случае HistoryRange для этой истории будет {1, 9, forward}
 * (последний известный эвент — 1-й, и нужно 9 эвентов).
 */
typedef list<Event> History;

/**
 * Упрощенные сведения о статусе машины
 */
union MachineStatus {
    1: MachineStatusWorking working
    2: MachineStatusFailed  failed
}

struct MachineStatusWorking {}
struct MachineStatusFailed {
    1: optional string reason
}

/**
 * Машина — конечный автомат, обрабатываемый State Processor'ом.
 */
struct Machine {
    /** Пространство имён, в котором работает машина */
    1: required base.Namespace ns;

    /** Основной идентификатор машины */
    2: required base.ID  id;

    /**
     * Сложное состояние, выраженное в виде упорядоченного набора событий
     * процессора.
     * Список событий упорядочен по моменту фиксирования его в
     * системе: в начале списка располагаются события, произошедшие
     * раньше тех, которые располагаются в конце.
     */
    3: required History history;

    /**
     * Диапазон с которым была запрошена история машины.
     */
    4: required HistoryRange history_range;

    /**
     * Упрощенный статус машины
     */
    8: optional MachineStatus status;

    /**
     * Вспомогательное состояние — это некоторый набор данных, характеризующий состояние,
     * и в отличие от событий не сохраняется в историю, а каждый раз перезаписывается.
     * Бывает полезен, чтобы сохранить данные между запросами, не добавляя их в историю.
     */
    7: optional AuxState aux_state;

    /**
     * Текущий активный таймер (точнее, дата и время когда таймер сработает).
     */
    6: optional base.Timestamp timer;

    // deallocated / reserved
    // 5: optional AuxStateLegacy aux_state_legacy

}

/**
 * Дескриптор машины
 */
struct MachineDescriptor {
    1: required base.Namespace ns;
    2: required Reference      ref;
    3: required HistoryRange   range;
}

/**
 * Желаемое действие, продукт перехода в новое состояние.
 *
 * Возможные действия представляют собой ограниченный язык для управления
 * прогрессом автомата, основанием для прихода сигналов или внешних вызовов,
 * которые приводят к дальнейшим переходам состояния. Отсутствие заполненных
 * полей будет интерпретировано буквально, как отсутствие желаемых действий.
 */
struct ComplexAction {
    3: optional TimerAction    timer;
    4: optional RemoveAction   remove;
}

/**
 * Дествие с таймером: установить(переустановить)/снять
 */
union TimerAction {
    1: SetTimerAction   set_timer;
    2: UnsetTimerAction unset_timer;
}

/**
 * Действие установки таймера ожидания на определённый отрезок времени.
 *
 * По истечению заданного отрезка времени в процессор поступит сигнал
 * `TimeoutSignal`.
 */
struct SetTimerAction {
    /** Критерий остановки таймера ожидания */
    1: required base.Timer      timer;
    /** История, с которой будет вызываться обработчик таймера. По умолчанию вся история. */
    2: optional HistoryRange    range;
    /** Таймаут, с которым будет вызываться обработчик таймера. По умолчанию 30 секунд. */
    3: optional base.Timeout    timeout;
}

/**
 * Действие отмены таймера.
 *
 * Если это действие явно не послать, то таймер будет активен.
 */
struct UnsetTimerAction {}

/**
 * Действие для удаления машины.
 * Исполняется последним. Если были эвенты, то они сохранятся.
 */
struct RemoveAction {}

 /**
 * Ссылка, уникально определяющая процесс автомата.
 */
union Reference {
    1: base.ID  id;   /** Основной идентификатор процесса автомата */
}

/**
 * Единица изменения _машины_.
 * По сути, это переход в стейте конечного автомата.
 */
struct MachineStateChange {
    /** Новый вспомогательный стейт автомата */
    3: optional AuxState      aux_state
    /** Список описаний событий, порождённых в результате обработки */
    4: optional EventBodies   events

    // deprecated / reserved
    // 1: optional AuxStateLegacy      aux_state_legacy
    // 2: optional EventBodiesLegacy   events_legacy
}

/**
 * Ответ на внешний вызов.
 */
typedef msgpack.Value CallResponse;

/**
 * Набор данных для обработки внешнего вызова.
 */
struct CallArgs {
    1: required Args     arg;      /** Данные вызова */
    2: required Machine  machine;  /** Данные по машине */
}

/**
 * Результат обработки внешнего вызова.
 */
struct CallResult {
    1: required CallResponse       response; /** Данные ответа */
    2: required MachineStateChange change;   /** Изменения _машины_ */
    3: required ComplexAction      action;   /** Действие, которое необходимо выполнить после обработки */
}

/**
 * Сигнал, который может поступить в автомат.
 *
 * Сигналы, как и частный их случай в виде вызовов, приводят к прогрессу
 * автомата и эволюции его состояния, то есть нарастанию истории.
 */
union Signal {
    1: InitSignal     init;
    2: TimeoutSignal  timeout;
    3: NotificationSignal notification;
}

/**
 * Сигнал, информирующий о запуске автомата.
 */
struct InitSignal {
    /** Набор данных для инициализации */
    1: required msgpack.Value   arg;
}

/**
 * Сигнал, информирующий об окончании ожидания по таймеру.
 */
struct TimeoutSignal {}

/**
 * Сигнал, информирующий о свершении события.
 */
struct NotificationSignal {
    1: required Args arguments
}

/**
 * Набор данных для обработки сигнала.
 */
struct SignalArgs {
    1: required Signal       signal;  /** Поступивший сигнал */
    2: required Machine      machine; /** Данные по машине */
}

/**
 * Результат обработки сигнала.
 */
struct SignalResult {
    1: required MachineStateChange change; /** Изменения _машины_ */
    2: required ComplexAction action;      /** _Действие_, которое необходимо выполнить после обработки _сигнала_ */
}

/**
 * Набор данных для обработки запроса на починку автомата.
 */
struct RepairArgs {
    1: required Args     arg;     /** Данные вызова */
    2: required Machine  machine; /** Данные по машине */
}

/**
 * Результат обработки запроса на починку автомата.
 */
struct RepairResult {
    1: required RepairResponse     response; /** Данные ответа */
    2: required MachineStateChange change;   /** Изменения _машины_ */
    3: required ComplexAction      action;   /** _Действие_, которое необходимо выполнить после обработки */
}

/**
 * Ответ на запрос о починке автомата.
 */
typedef msgpack.Value RepairResponse

/**
 * Исключение при неуспешной обработке запроса на починку автомата.
 */
exception RepairFailed {
    1: required msgpack.Value reason;
}

/**
 * Процессор переходов состояния ограниченного конечного автомата.
 *
 * В результате вызова каждого из методов сервиса должны появиться новое
 * состояние и новые действия, приводящие к дальнейшему прогрессу автомата.
 */
service Processor {

    /**
     * Обработать поступивший сигнал.
     */
    SignalResult ProcessSignal (1: SignalArgs a) throws ()

    /**
     * Обработать внешний вызов и сформировать ответ на него.
     */
    CallResult ProcessCall (1: CallArgs a) throws ()

    /**
     * Обработать запрос на починку и сформировать ответ на него.
     */
    RepairResult ProcessRepair (1: RepairArgs a)
        throws (1: RepairFailed ex1)

}

struct MachineEvent {
    /** Пространство имён, в котором работает машина */
    1: required base.Namespace ns
    /** Основной идентификатор машины */
    2: required base.ID  id
    /** Событие машины */
    3: required Event event
}

struct ModernizeEventResult {
    /** Обновлённое представление события */
    1: required EventBody event_payload
}

/**
 * Сервис обновления устаревших представлений данных машины.
 */
service Modernizer {

    ModernizeEventResult ModernizeEvent (1: MachineEvent ev) throws ()

}

enum Direction {
    forward  = 1
    backward = 2
}

/**
 * Структура задает параметры для выборки событий
 *
 */
struct HistoryRange {
    /**
     * Идентификатор события, после которого следуют события,
     * входящие в описываемую выборку. Если поле не указано,
     * то в выборку попадут события с самого первого.
     *
     * Если `after` не указано, в выборку попадут события с начала истории; если
     * указано, например, `42`, то в выборку попадут события, случившиеся _после_
     * события `42`.
     */
    1: optional base.EventID after

    /**
     * Максимальная длина выборки.
     * Допустимо указывать любое значение >= 0.
     *
     * Если поле не задано, то длина выборки ничем не ограничена.
     *
     * Если в выборку попало событий _меньше_, чем значение `limit`,
     * был достигнут конец текущей истории.
     */
    2: optional i32 limit

    /**
     * Направление истории, по-умолчанию вперёд.
     */
    3: optional Direction direction = Direction.forward
}

// Уникальный в рамках неймспейса идентификатор нотификации
typedef string NotificationID

struct NotifyResponse {
    1: required NotificationID id
}

/**
 * Сервис управления процессами автоматов, отвечающий за реализацию желаемых
 * действий и поддержку состояния процессоров.
 *
 * Для всех методов сервиса справедливы следующие утверждения:
 *  - если в параметре к методу передан Reference с ссылкой на машину, которой не
 *    существует, то метод выкинет исключение MachineNotFound
 *  - если в структуре HistoryRange поле after содержит несуществующий id события,
 *    то метод выкинет исключение EventNotFound
 *  - если в процессе выполнения запроса машина перешла в некорректное состояние
 *    то метод выкинет исключение MachineFailed
 */
service Automaton {

    /**
     * Запустить новый процесс автомата с заданным ID.
     * Если машина с таким ID уже существует, то кинется иключение MachineAlreadyExists.
     */
    void Start (1: base.Namespace ns, 2: base.ID id, 3: Args a)
        throws (1: NamespaceNotFound ex1, 2: MachineAlreadyExists ex2, 3: MachineFailed ex3);

    /**
     * Попытаться перевести определённый процесс автомата из ошибочного состояния
     * в штатное и, получив результат операции, продолжить его исполнение.
     */
    RepairResponse Repair (1: MachineDescriptor desc, 2: Args a)
        throws (
            1: NamespaceNotFound ex1,
            2: MachineNotFound ex2,
            3: MachineFailed ex3,
            4: MachineAlreadyWorking ex4,
            5: RepairFailed ex5
        );

    /**
     * Попытаться перевести определённый процесс автомата из ошибочного
     * состояния в предыдущее штатное и продолжить его исполнение.
     */
    void SimpleRepair (1: base.Namespace ns, 2: Reference ref)
        throws (1: NamespaceNotFound ex1, 2: MachineNotFound ex2, 3: MachineFailed ex3, 4: MachineAlreadyWorking ex4);

    /**
     * Совершить вызов и дождаться на него ответа.
     */
    CallResponse Call (1: MachineDescriptor desc, 2: Args a)
        throws (1: NamespaceNotFound ex1, 2: MachineNotFound ex2, 3: MachineFailed ex3);

    /**
     * Метод возвращает _машину_ (Machine)
     */
    Machine GetMachine (1: MachineDescriptor desc)
        throws (1: NamespaceNotFound ex1, 2: MachineNotFound ex2, 3: EventNotFound ex3);

    /**
     * Удалить машину вместе со всеми её событиями.
     * Опубликованные в event sink события остаются нетронутыми.
     */
    void Remove (1: base.Namespace ns, 2: base.ID id)
        throws (1: NamespaceNotFound ex1, 2: MachineNotFound ex2);

    /**
     * Принудительно обновить представления данных указанной машины.
     * В частности: представления событий.
     */
    void Modernize (1: MachineDescriptor desc)
        throws (1: NamespaceNotFound ex1, 2: MachineNotFound ex2);

    /**
     * Уведомить автомат о каком-либо событии.
     * Например, обновлении состояния "дочернего" автомата.
     */
    NotifyResponse Notify (1: MachineDescriptor desc, 2: Args a)
        throws (1: NamespaceNotFound ex1, 2: MachineNotFound ex2)
}

/**
 * Событие, содержащее в себе событие и его источник.
 */
struct SinkEvent {
    /**
     * Идентификатор эвента EventSink'а, он отличается от идентификатора эвента машины.
     * Эти идентификаторы total ordered, и они же используются для EventSink:GetHistory.
     */
    1: required base.EventID    id;
    2: required base.ID         source_id;      /* Идентификатор объекта, породившего событие */
    3: required base.Namespace  source_ns;      /* Идентификатор пространства имён, породившего событие */
    4: required Event           event;          /* Исходное событие */
}

/**
 * Сложное состояние всей системы (всех машин), выраженное в виде упорядоченного набора событий.
 */
typedef list<SinkEvent> SinkHistory;

exception EventSinkNotFound {}

/**
 * Сервис получения истории событий сразу всех машин.
 */
service EventSink {
    /**
     * Метод возвращает список событий (историю) всех машин системы, включая
     * те машины, которые существовали в прошлом, но затем были удалены.
     *
     * Возвращаемый список событий упорядочен по моменту фиксирования его в
     * системе: в начале списка располагаются события, произошедшие
     * раньше тех, которые располагаются в конце.
     */
    SinkHistory GetHistory (1: base.ID event_sink_id, 2: HistoryRange range)
         throws (1: EventSinkNotFound ex1, 2: EventNotFound ex2, 3: base.InvalidRequest ex3);
}
