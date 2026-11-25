// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get language => 'Язык';

  @override
  String get mySchedule => 'Моё расписание';

  @override
  String get today => 'Сегодня';

  @override
  String get retry => 'Повторить';

  @override
  String get loadLessonsFailed =>
      'Не удалось загрузить уроки. Попробуйте ещё раз.';

  @override
  String noLessonsOn(String date) {
    return '$date у вас нет уроков.';
  }

  @override
  String nowFor(String duration) {
    return 'Сейчас · $duration';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes мин';
  }

  @override
  String durationHours(int hours) {
    return '$hours ч';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours ч $minutes мин';
  }

  @override
  String get substitution => 'Замена';

  @override
  String get cancelled => 'Отменён';

  @override
  String get meeting => 'Собрание';

  @override
  String get untitled => 'Без названия';

  @override
  String periodShort(int number) {
    return '$number ур.';
  }

  @override
  String get noLessonRecord =>
      'На эту дату нет записи урока для оценивания: дата раньше начала опубликованного расписания, праздник или запись ещё не создана.';

  @override
  String get attendance => 'Посещаемость';

  @override
  String get scores => 'Оценки';

  @override
  String get present => 'Есть';

  @override
  String get late => 'Опоздал';

  @override
  String get absent => 'Нет';

  @override
  String get excused => 'По причине';

  @override
  String get presentShort => 'Е';

  @override
  String get lateShort => 'О';

  @override
  String get absentShort => 'Н';

  @override
  String get excusedShort => 'П';

  @override
  String minutesShort(int minutes) {
    return '$minutesм';
  }

  @override
  String get minutesHint => 'мин';

  @override
  String get materials => 'Тетради';

  @override
  String get homeworkDone => 'ДЗ есть';

  @override
  String get homework => 'ДЗ верно';

  @override
  String get activity => 'Активность';

  @override
  String get notes => 'Конспект';

  @override
  String get next => 'Далее';

  @override
  String get saveAndNext => 'Сохранить и далее';

  @override
  String get save => 'Сохранить';

  @override
  String get skip => 'Пропустить';

  @override
  String get saved => 'Сохранено';

  @override
  String get attendanceSaved => 'Посещаемость сохранена';

  @override
  String get scoresSaved => 'Оценки сохранены';

  @override
  String studentsCount(int count) {
    return 'Учеников: $count';
  }

  @override
  String addMinutesForLate(int count) {
    return 'Укажите минуты опоздания: $count';
  }

  @override
  String needFixing(int count) {
    return 'Исправить: $count';
  }

  @override
  String toSave(int count) {
    return 'К сохранению: $count';
  }

  @override
  String get fixHighlightedRows => 'Сначала исправьте выделенные строки';

  @override
  String get lessonCancelledBanner =>
      'Этот урок отменён; оценки только для чтения.';

  @override
  String lessonCancelledReasonBanner(String reason) {
    return 'Этот урок отменён ($reason); оценки только для чтения.';
  }

  @override
  String get windowClosedBanner =>
      'Оценки можно менять 3 дня после урока, но не позже субботы 08:00. Для исправления обратитесь к администратору.';

  @override
  String get noStudents => 'На эту дату в классе нет учеников.';

  @override
  String get unsavedTitle => 'Несохранённые изменения';

  @override
  String get unsavedBody => 'Выйти без сохранения изменений?';

  @override
  String get stay => 'Остаться';

  @override
  String get leave => 'Выйти';

  @override
  String get commentHint => 'Комментарий';

  @override
  String get whyBelow40 => 'Почему ниже 40? (обязательно)';

  @override
  String get noteOptional => 'Заметка (необязательна при выборе причины)';

  @override
  String get foldAll => 'Свернуть всё';

  @override
  String get unfoldAll => 'Развернуть всё';

  @override
  String get uploads => 'Загрузки';

  @override
  String get tryNow => 'Повторить сейчас';

  @override
  String notAccepted(String reason) {
    return 'Не принято: $reason';
  }

  @override
  String waitingForConnection(int tries) {
    return 'Ожидание связи (попыток: $tries)';
  }

  @override
  String get discard => 'Удалить';

  @override
  String get behavior => 'Поведение';

  @override
  String waitingToUpload(int count) {
    return 'Ожидают загрузки: $count';
  }

  @override
  String notAcceptedCount(int count) {
    return 'Не принято: $count';
  }

  @override
  String signOutUnsent(int count) {
    return 'Сохранений на этом телефоне: $count. Если выйти, они будут потеряны.';
  }

  @override
  String get home => 'Главная';

  @override
  String get schedule => 'Мой график';

  @override
  String get classShort => 'Класс';

  @override
  String get myClass => 'Мой класс';

  @override
  String get grades => 'Оценки';

  @override
  String get exams => 'Экзамены';

  @override
  String get timetable => 'Расписание';

  @override
  String get rewards => 'Награды';

  @override
  String get colleagues => 'Коллеги';

  @override
  String get pointReport => 'Отчёт по баллам';

  @override
  String get profile => 'Профиль';

  @override
  String hiName(String name) {
    return 'Привет, $name';
  }

  @override
  String lessonsExamsCount(int lessons, int exams) {
    return 'Уроки: $lessons · Экзамены: $exams';
  }

  @override
  String get loadFailed => 'Не удалось загрузить. Проверьте соединение.';

  @override
  String get noClassesYet => 'Вам пока не назначены классы.';

  @override
  String get noGradesYet => 'Оценок пока нет.';

  @override
  String get all => 'Все';

  @override
  String get student => 'Ученик';

  @override
  String get averageShort => 'Ср.';

  @override
  String get examsShort => 'Экз.';

  @override
  String get reportStudent => 'Отчёт об ученике';

  @override
  String get reportShort => 'Отчёт';

  @override
  String get markTab => 'Отметить';

  @override
  String get historyTab => 'История';

  @override
  String get statisticsTab => 'Статистика';

  @override
  String get stepWho => 'Кто';

  @override
  String get stepWhatKind => 'Какой';

  @override
  String get stepWhy => 'Почему';

  @override
  String get searchAnyStudent => 'Поиск любого ученика…';

  @override
  String get otherClass => 'Другой класс…';

  @override
  String get mine => 'мой';

  @override
  String get selectAll => 'Выбрать всех';

  @override
  String get unselectAll => 'Снять выбор';

  @override
  String get tapStudentsFirst => 'Сначала выберите учеников';

  @override
  String nextWho(String who) {
    return 'Далее · $who';
  }

  @override
  String get pickOneAbove => 'Выберите вариант выше';

  @override
  String get pickReasonOrComment => 'Выберите причину или напишите комментарий';

  @override
  String saveForWho(String who) {
    return 'Сохранить: $who';
  }

  @override
  String savedForWho(String who) {
    return 'Сохранено: $who';
  }

  @override
  String get seeInHistory => 'Посмотреть в истории';

  @override
  String get markMore => 'Отметить ещё';

  @override
  String markMoreIn(String cls) {
    return 'Отметить ещё в $cls';
  }

  @override
  String get back => 'Назад';

  @override
  String get positive => 'Положительно';

  @override
  String get needsAttention => 'Требует внимания';

  @override
  String get positiveDetail => 'То, что стоит похвалить';

  @override
  String get negativeDetail => 'То, над чем стоит поработать';

  @override
  String get addCommentOptional => 'Добавьте комментарий (необязательно)';

  @override
  String get noStudentNamed => 'Ученика с таким именем нет.';

  @override
  String get noStudentsInClass => 'В этом классе нет учеников.';

  @override
  String get loadingStudents => 'Загрузка учеников…';

  @override
  String acrossSchool(int count) {
    return '$count по всей школе';
  }

  @override
  String get studentOrClass => 'Ученик или класс';

  @override
  String get noFilterMatches => 'По этим фильтрам ничего нет.';

  @override
  String get noBehaviorMarks => 'Отметок о поведении пока нет.';

  @override
  String get from => 'С';

  @override
  String get to => 'По';

  @override
  String get total => 'Всего';

  @override
  String get byClass => 'По классам';

  @override
  String get byWeek => 'По неделям';

  @override
  String get commonReasons => 'Частые причины';

  @override
  String get noMarksForPeriod => 'За этот период отметок нет.';

  @override
  String get myPlan => 'Мой план';

  @override
  String get myPoints => 'Мои баллы';

  @override
  String get myFundings => 'Мои накопления';

  @override
  String get teachingTools => 'Инструменты урока';

  @override
  String get teachingShort => 'Урок';

  @override
  String get thisMonth => 'Этот месяц';

  @override
  String get last30Days => 'Последние 30 дней';

  @override
  String get thisYear => 'Этот год';

  @override
  String get moreFilters => 'Другие фильтры';

  @override
  String get allCategories => 'Все категории';

  @override
  String historyCount(int count) {
    return 'История ($count)';
  }

  @override
  String inThisPeriod(String amount) {
    return '$amount за этот период';
  }

  @override
  String get noPointsYet => 'Здесь появятся начисленные и снятые баллы.';

  @override
  String get nothingInPeriod => 'За этот период ничего нет.';

  @override
  String get noSavingsYet => 'Здесь появятся ваши накопления.';

  @override
  String get showAmounts => 'Показать суммы';

  @override
  String get hideAmounts => 'Скрыть суммы';

  @override
  String get currencySom => 'сум';

  @override
  String get received => 'Получено';

  @override
  String get withdrawn => 'Снято';

  @override
  String get balance => 'Баланс';

  @override
  String get addMilestone => 'Добавить этап';

  @override
  String get editMilestone => 'Изменить этап';

  @override
  String get milestones => 'Этапы';

  @override
  String get noPlanYet =>
      'Плана пока нет. Разбейте год на этапы и отмечайте выполненные.';

  @override
  String get noMilestonesWithStatus => 'С таким статусом ничего нет.';

  @override
  String get planNotStarted => 'Не начато';

  @override
  String get planInProgress => 'В работе';

  @override
  String get planDone => 'Готово';

  @override
  String get planPostponed => 'Отложено';

  @override
  String get planCancelled => 'Отменено';

  @override
  String get overdue => 'Просрочено';

  @override
  String get priority => 'Приоритет';

  @override
  String get priorityLow => 'Низкий';

  @override
  String get priorityMedium => 'Средний';

  @override
  String get priorityHigh => 'Высокий';

  @override
  String get priorityUrgent => 'Срочный';

  @override
  String get status => 'Статус';

  @override
  String get category => 'Категория';

  @override
  String get categoryCurriculum => 'Программа';

  @override
  String get categoryLesson => 'Урок';

  @override
  String get categoryExam => 'Экзамен';

  @override
  String get categoryMeeting => 'Собрание';

  @override
  String get categoryAdministrative => 'Административное';

  @override
  String get categoryPersonal => 'Личное';

  @override
  String get categoryGeneral => 'Общее';

  @override
  String get starts => 'Начало';

  @override
  String get ends => 'Конец';

  @override
  String get milestoneTitleHint => 'Название, например: алгебра, 1 четверть';

  @override
  String get addFiles => 'Добавить файлы';

  @override
  String fileTooBig(String name) {
    return '$name больше 10 МБ';
  }

  @override
  String get milestoneNeedsTitle => 'Укажите название этапа';

  @override
  String get endBeforeStart => 'Дата окончания не может быть раньше начала';

  @override
  String get milestoneAdded => 'Этап добавлен';

  @override
  String get milestoneUpdated => 'Этап обновлён';

  @override
  String get milestoneDeleted => 'Этап удалён';

  @override
  String get couldNotSaveMilestone => 'Не удалось сохранить этап';

  @override
  String get couldNotDeleteMilestone => 'Не удалось удалить этап';

  @override
  String get planStatusFailed => 'Не удалось обновить статус';

  @override
  String get deleteMilestoneTitle => 'Удалить этот этап?';

  @override
  String deleteMilestoneBody(String agenda) {
    return '«$agenda» и его файлы будут удалены. Это нельзя отменить.';
  }

  @override
  String get cancel => 'Отмена';

  @override
  String get delete => 'Удалить';

  @override
  String get soon => 'Скоро';

  @override
  String get teamShuffle => 'Деление на команды';

  @override
  String get namePicker => 'Выбор имени';

  @override
  String get timer => 'Таймер';

  @override
  String get participation => 'Активность';

  @override
  String get homeworkCheck => 'Проверка ДЗ';

  @override
  String get balancedTeams => 'Равные команды';

  @override
  String get seatingPlan => 'План рассадки';

  @override
  String get done => 'Готово';

  @override
  String get absentQuestion => 'Кто отсутствует?';

  @override
  String get startOver => 'Сначала';

  @override
  String get fewerTeams => 'Меньше команд';

  @override
  String get moreTeams => 'Больше команд';

  @override
  String get roles => 'Роли';

  @override
  String get shuffle => 'Разделить';

  @override
  String get again => 'Ещё раз';

  @override
  String get teamRed => 'Красные';

  @override
  String get teamBlue => 'Синие';

  @override
  String get teamGreen => 'Зелёные';

  @override
  String get teamYellow => 'Жёлтые';

  @override
  String get teamPurple => 'Фиолетовые';

  @override
  String get teamOrange => 'Оранжевые';

  @override
  String get teamPink => 'Розовые';

  @override
  String get teamTeal => 'Бирюзовые';

  @override
  String get roleLeader => 'Лидер';

  @override
  String get roleTimekeeper => 'Хранитель времени';

  @override
  String get roleRecorder => 'Секретарь';

  @override
  String get roleReporter => 'Докладчик';

  @override
  String get roleChecker => 'Проверяющий';

  @override
  String get roleEncourager => 'Вдохновитель';

  @override
  String get roleMaterials => 'Материалы';

  @override
  String get roleQuestioner => 'Спрашивающий';

  @override
  String get roleHelper => 'Помощник';

  @override
  String get oneMinuteLess => 'На минуту меньше';

  @override
  String get oneMinuteMore => 'На минуту больше';

  @override
  String get pause => 'Пауза';

  @override
  String get start => 'Старт';

  @override
  String get reset => 'Сброс';

  @override
  String get comingSoon => 'Скоро';

  @override
  String get comingSoonBody => 'Этот раздел приложения пока не готов.';

  @override
  String get search => 'Поиск';

  @override
  String get notifications => 'Уведомления';

  @override
  String get searchHint => 'Разделы, ученики, коды…';

  @override
  String get searchPagesHint => 'Поиск по приложению…';

  @override
  String get searchSuggested => 'Рекомендуем';

  @override
  String get searchPages => 'Разделы';

  @override
  String get searchPeople => 'Люди';

  @override
  String searchFound(int count) {
    return 'Найдено: $count';
  }

  @override
  String searchMinChars(int count) {
    return 'Введите $count буквы, чтобы искать людей';
  }

  @override
  String searchNothing(String query) {
    return 'По запросу «$query» ничего не найдено';
  }

  @override
  String get searchNothingBody =>
      'Попробуйте другое написание, код ученика или название раздела.';

  @override
  String get searchNothingPagesBody => 'Попробуйте другое слово для раздела.';

  @override
  String get searchShowMore => 'Показать ещё';

  @override
  String get searchLeft => 'Выбыл';

  @override
  String searchGrade(int grade) {
    return '$grade класс';
  }

  @override
  String get searchFailed => 'Не удалось найти людей.';

  @override
  String colleaguesActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count активных коллег',
      few: '$count активных коллеги',
      one: '$count активный коллега',
    );
    return '$_temp0';
  }

  @override
  String get colleaguesNone => 'Коллеги не найдены.';

  @override
  String get colleaguesNoneMatching => 'По запросу коллеги не найдены.';

  @override
  String get colleaguesNoPhone => 'Нет номера телефона';

  @override
  String colleaguesCall(String name) {
    return 'Позвонить: $name';
  }

  @override
  String colleaguesMessage(String name) {
    return 'SMS: $name';
  }

  @override
  String get colleaguesCopied => 'Номер скопирован';

  @override
  String get colleaguesCantCall => 'Не удалось открыть приложение телефона.';

  @override
  String get colleaguesLoadFailed => 'Не удалось загрузить коллег.';

  @override
  String get clearSearch => 'Очистить поиск';

  @override
  String get resetFilters => 'Сбросить фильтры';

  @override
  String pointsFor(String date) {
    return 'За $date';
  }

  @override
  String get pointsEdited => 'изменено';

  @override
  String get pointsRefreshFailed => 'Не удалось обновить баллы.';

  @override
  String get pointsWiderPeriod => 'Выберите период пошире.';

  @override
  String get colleaguesSwipeCall => 'Позвонить';

  @override
  String get colleaguesSwipeMessage => 'Сообщение';

  @override
  String get classStudentsTab => 'Ученики';

  @override
  String get classGradesTab => 'Оценки';

  @override
  String get classBehaviorTab => 'Поведение';

  @override
  String classStudentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count учеников',
      few: '$count ученика',
      one: '$count ученик',
    );
    return '$_temp0';
  }

  @override
  String get classLeft => 'Выбыл';

  @override
  String get classPresent => 'Учится';

  @override
  String get classContacts => 'Контакты';

  @override
  String get classNoContacts => 'Контактов пока нет.';

  @override
  String get classEditContacts => 'Изменить контакты';

  @override
  String get classNoStudents => 'В этом классе нет учеников.';

  @override
  String get classNoHomeroom => 'Класс не назначен';

  @override
  String get classNoHomeroomBody => 'В этом году вы не классный руководитель.';

  @override
  String get classGradesNone => 'Оценок пока нет';

  @override
  String get classGradesFailed => 'Не удалось загрузить оценки.';

  @override
  String get classDaily => 'Ежедн.';

  @override
  String get classGraded => 'С оценкой';

  @override
  String get classCatAttend => 'Посещ.';

  @override
  String get classCatBooks => 'Книги';

  @override
  String get classCatHomework => 'ДЗ';

  @override
  String get classCatActive => 'Актив.';

  @override
  String get classCatNotes => 'Тетр.';

  @override
  String get classBehaviorFailed => 'Не удалось загрузить поведение.';

  @override
  String get classPositive => 'Положительные';

  @override
  String get classNeedsAttention => 'Требует внимания';

  @override
  String get classMark => 'Отметить';

  @override
  String get classNoMarks => 'Отметок пока нет';

  @override
  String classAllMarks(int count) {
    return 'Все: $count';
  }

  @override
  String notMarkedCount(int count) {
    return 'Не отмечено: $count';
  }

  @override
  String get allMarked => 'Все отмечены';

  @override
  String get notMarked => 'не отмечен';

  @override
  String notFinished(int count) {
    return 'Не закончено: $count';
  }

  @override
  String scoreEveryCategory(int count) {
    return 'Сначала оцените все категории ($count уч.)';
  }

  @override
  String get oldGradingLesson =>
      'урок отмечен до новой системы оценок, поэтому действуют старые категории';

  @override
  String get profileAccount => 'Аккаунт';

  @override
  String get profileApp => 'Приложение';

  @override
  String get profileEmail => 'Email';

  @override
  String get profilePhone => 'Телефон';

  @override
  String get profilePassword => 'Пароль';

  @override
  String get profileSystem => 'Система';

  @override
  String get profileSystemHint => 'Язык, цвет, тёмная тема';

  @override
  String get profileSuggestions => 'Предложения';

  @override
  String get profileLogOut => 'Выйти';

  @override
  String get profileNotSet => 'Не указано';

  @override
  String get profileContactTitle => 'Контактные данные';

  @override
  String get profileInvalidEmail => 'Введите корректный email';

  @override
  String get profileInvalidPhone => 'Введите корректный номер телефона';

  @override
  String get profileContactSaved => 'Контактные данные обновлены';

  @override
  String get profileContactFailed => 'Не удалось обновить контактные данные';

  @override
  String get suggestionsLead => 'Идеи, проблемы, вопросы — мы читаем каждое.';

  @override
  String get suggestionsPrompt => 'Что нам улучшить?';

  @override
  String get suggestionsHint => 'Напишите предложение…';

  @override
  String get suggestionsAnonymous => 'Анонимно';

  @override
  String get suggestionsSend => 'Отправить';

  @override
  String get suggestionsSentButton => 'Отправлено';

  @override
  String get suggestionsSent => 'Отправлено — спасибо!';

  @override
  String get suggestionsFailed => 'Не удалось отправить. Попробуйте ещё раз.';

  @override
  String get edit => 'Изменить';

  @override
  String get calendar => 'Календарь';

  @override
  String get calToday => 'Сегодня';

  @override
  String get calMonthView => 'Месяц';

  @override
  String get calScheduleView => 'Список';

  @override
  String get calNewEvent => 'Новое событие';

  @override
  String get calEditEvent => 'Изменить событие';

  @override
  String get calEvents => 'События';

  @override
  String get calHolidays => 'Праздники';

  @override
  String get calTerms => 'Четверти';

  @override
  String get calExams => 'Экзамены';

  @override
  String get calAllEvents => 'Все события';

  @override
  String get calNothingOnDay => 'В этот день ничего нет';

  @override
  String get calEvent => 'Событие';

  @override
  String get calHoliday => 'Праздник';

  @override
  String get calTermStarts => 'Начало четверти';

  @override
  String get calTermEnds => 'Конец четверти';

  @override
  String get calExamPeriod => 'Период экзаменов';

  @override
  String get calAllDay => 'Весь день';

  @override
  String get calCancelled => 'Отменено';

  @override
  String get calDraft => 'Черновик';

  @override
  String get calCancelEvent => 'Отменить событие';

  @override
  String get calCancelEventQ => 'Отменить событие?';

  @override
  String get calDeleteEventQ => 'Удалить событие?';

  @override
  String get calEventCancelled => 'Событие отменено';

  @override
  String get calEventDeleted => 'Событие удалено';

  @override
  String get calChangeFailed => 'Не удалось сохранить';

  @override
  String get calTitle => 'Название';

  @override
  String get calTitleRequired => 'Введите название';

  @override
  String get calCategory => 'Категория';

  @override
  String get calLocation => 'Место';

  @override
  String get calDescription => 'Описание';

  @override
  String get calAudience => 'Кто видит';

  @override
  String get calAddAudience => 'Добавить';

  @override
  String get calAllStaff => 'Все сотрудники';

  @override
  String get calAllStudents => 'Все ученики';

  @override
  String get calGrade => 'Параллель';

  @override
  String get calClass => 'Класс';

  @override
  String get calRole => 'Роль';

  @override
  String get calDepartment => 'Кафедра';

  @override
  String get calSaveAsDraft => 'Сохранить как черновик';

  @override
  String get calNotify => 'Отправить уведомление';

  @override
  String get calCatGeneral => 'Общее';

  @override
  String get calCatCeremony => 'Церемония';

  @override
  String get calCatParentMeeting => 'Родительское собрание';

  @override
  String get calCatTrip => 'Поездка';

  @override
  String get calCatSports => 'Спорт';

  @override
  String get calCatCompetition => 'Соревнование';

  @override
  String get calCatDeadline => 'Дедлайн';

  @override
  String get calCatStaff => 'Сотрудники';

  @override
  String get calCatOther => 'Другое';

  @override
  String get myLessonAnalysis => 'Результаты анализа уроков';

  @override
  String get myAnalysisShort => 'Мой анализ';

  @override
  String get lessonAnalysis => 'Анализ уроков';

  @override
  String get laNoneYet =>
      'Пока нет анализов. Когда ваш урок проанализируют, результаты появятся здесь.';

  @override
  String get laTotalPoints => 'Всего баллов';

  @override
  String get laThisMonth => 'Этот месяц';

  @override
  String get laLastMonth => 'Прошлый месяц';

  @override
  String get laAllTime => 'За всё время';

  @override
  String get laAnalyses => 'Анализы';

  @override
  String get laLatest => 'Последний';

  @override
  String laNotesCount(int count) {
    return 'Заметок: $count';
  }

  @override
  String get laNoNotes => 'Без заметок';

  @override
  String get laMyDepartment => 'Моя кафедра';

  @override
  String laAnalysedOf(int analysed, int total) {
    return 'Проанализировано $analysed из $total учителей';
  }

  @override
  String laAnalysesCount(int count) {
    return 'Анализов: $count';
  }

  @override
  String get laNotAnalysed => 'Ещё не анализировали';

  @override
  String get laSortLast => 'Последний анализ';

  @override
  String get laSortMost => 'Больше баллов';

  @override
  String get laSortLeast => 'Меньше баллов';

  @override
  String get laSortName => 'Имя';

  @override
  String get laNewAnalysis => 'Новый анализ';

  @override
  String get laEditAnalysis => 'Изменить анализ';

  @override
  String get laDeleteQ => 'Удалить анализ?';

  @override
  String get laDeleteBody => 'Баллы будут сняты с учителя.';

  @override
  String get laDeleted => 'Анализ удалён';

  @override
  String get laTeacher => 'Учитель';

  @override
  String get laLesson => 'Урок';

  @override
  String get laNoLessons => 'За последние 60 дней нет уроков для анализа.';

  @override
  String get laAnalysed => 'проанализирован';

  @override
  String get laPoints => 'Баллы';

  @override
  String get laNotes => 'Заметки';

  @override
  String get laChooseTeacher => 'Выберите учителя';

  @override
  String get laChooseLesson => 'Выберите урок';

  @override
  String get laPointsWhole => 'Баллы должны быть целым числом';

  @override
  String get laSaved => 'Сохранено';

  @override
  String get laSaveFailed => 'Не удалось сохранить анализ';

  @override
  String get myDepartment => 'Моя кафедра';

  @override
  String get deptNone => 'Вы не руководите кафедрой.';

  @override
  String get deptHead => 'Руководитель';

  @override
  String get deptDeputy => 'Заместитель';

  @override
  String deptCounts(int subjects, int members) {
    return 'Предметов: $subjects · участников: $members';
  }

  @override
  String get deptLessons => 'Уроки';

  @override
  String get deptAttendanceTaken => 'Посещаемость отмечена';

  @override
  String get deptGradesEntered => 'Оценки выставлены';

  @override
  String get deptGrades => 'Оценки';

  @override
  String get deptAvgGrade => 'Средняя оценка';

  @override
  String get deptAttendance => 'Посещаемость';

  @override
  String get deptExamAvg => 'Средний за экзамен';

  @override
  String get deptKpi => 'KPI';

  @override
  String get deptTeachers => 'Учителя';

  @override
  String get deptSubjects => 'Предметы';

  @override
  String get deptClasses => 'Классы';

  @override
  String get deptAllClasses => 'Все классы';

  @override
  String get cashier => 'Касса';

  @override
  String get cashReview => 'Отметки поведения без причины';

  @override
  String get cashSync => 'Синхронизировать оценки';

  @override
  String get cashSyncFailed => 'Синхронизация не удалась';

  @override
  String cashSyncedThrough(String date) {
    return 'Синхронизировано по $date';
  }

  @override
  String get cashClasses => 'Классы';

  @override
  String get cashRanking => 'Рейтинг школы';

  @override
  String get cashSearch => 'Имя ученика';

  @override
  String get cashAmount => 'Сумма';

  @override
  String get cashNote => 'Заметка';

  @override
  String get cashSpend => 'Списать';

  @override
  String get cashAdd => 'Добавить';

  @override
  String get cashResetQ => 'Обнулить баланс до \$0?';

  @override
  String get cashResetZero => 'Обнулить до \$0';

  @override
  String get cashHistory => 'История';

  @override
  String get cashNoHistory => 'Истории пока нет';

  @override
  String get attendanceCheck => 'Посещаемость';

  @override
  String get attNotMarked => 'Не отмечено';

  @override
  String get attOnNow => 'Идёт сейчас';

  @override
  String get attMarked => 'Отмечено';

  @override
  String get attLater => 'Позже';

  @override
  String get attNoStudents => 'Нет учеников';

  @override
  String get attOnlyMissing => 'Только классы с неотмеченными уроками';

  @override
  String get attNoLessons => 'В этот день нет уроков';

  @override
  String get attAbsent => 'Отсутствуют';

  @override
  String get attLate => 'Опоздали';

  @override
  String get attStatistics => 'Статистика посещаемости';

  @override
  String get attThisWeek => 'Эта неделя';

  @override
  String get attThisMonth => 'Этот месяц';

  @override
  String get attAttendanceRate => 'Процент посещаемости';

  @override
  String get attPresent => 'Присутствовали';

  @override
  String get attExcused => 'Уважительная причина';

  @override
  String get attByClass => 'По классам';

  @override
  String get attByStudent => 'По ученикам';

  @override
  String get attNoMarks => 'Нет отметок за этот период';

  @override
  String get substitutions => 'Замены';

  @override
  String get subNewAbsence => 'Новое отсутствие';

  @override
  String get subNone => 'За эти две недели замен нет';

  @override
  String get subNoLessonsYet =>
      'Уроки ещё не распределены — нажмите на отсутствие.';

  @override
  String subLessonsCount(int count) {
    return 'Уроков: $count';
  }

  @override
  String get subRemove => 'Убрать';

  @override
  String get subRemoveQ => 'Убрать замену?';

  @override
  String subRemoveBody(String lesson, String time) {
    return '$lesson в $time вернётся к своему учителю. Никто не будет уведомлён.';
  }

  @override
  String get subRemoved => 'Замена убрана';

  @override
  String get subCover => 'Замена';

  @override
  String get subMerge => 'Объединить';

  @override
  String get subCancel => 'Отменить';

  @override
  String get subNext => 'Далее';

  @override
  String get subReasonSick => 'Болезнь';

  @override
  String get subReasonPersonal => 'Личное';

  @override
  String get subReasonTrip => 'Командировка';

  @override
  String get subReasonTraining => 'Обучение';

  @override
  String subCoverFor(String name) {
    return 'Замена для $name';
  }

  @override
  String get subNoAffected => 'У этого отсутствия нет уроков.';

  @override
  String get subArranged => 'Уже распределены';

  @override
  String get subPickEach => 'Выберите замену или урок для каждого';

  @override
  String get subSaved => 'Замены сохранены';

  @override
  String get subBusy => 'занят';

  @override
  String get subAbsent => 'отсутствует';

  @override
  String get subUnavailable => 'недоступен';

  @override
  String get subSubject => 'предмет';

  @override
  String get subKnowsClass => 'знает класс';

  @override
  String subCoversMonth(int count) {
    return '$count замен/мес';
  }

  @override
  String get subSubstitute => 'Замещающий';

  @override
  String get subMergeWith => 'Объединить с';

  @override
  String get subAssignAnyway => 'Назначить всё равно';

  @override
  String get staffPoints => 'Баллы сотрудников';

  @override
  String get spAward => 'Начислить баллы';

  @override
  String get spAwardShort => 'Начислить';

  @override
  String get spDeduct => 'Снять';

  @override
  String get spThisWeek => 'Эта неделя';

  @override
  String get spThisYear => 'Этот год';

  @override
  String get spChooseRecipients => 'Выберите кому';

  @override
  String get spAllTeachers => 'Все учителя';

  @override
  String get spNoCategory => 'Без категории';

  @override
  String get spNoteRequired => 'Напишите заметку';

  @override
  String spSaved(int count) {
    return 'Сохранено для $count';
  }

  @override
  String spSomeFailed(int count) {
    return 'Не удалось сохранить: $count';
  }

  @override
  String get fundings => 'Накопления';

  @override
  String get fundNew => 'Новая запись';

  @override
  String get fundNone => 'Накоплений пока нет';

  @override
  String get fundDeposits => 'Взносы';

  @override
  String get fundWithdrawals => 'Снятия';

  @override
  String get fundBalance => 'Баланс';

  @override
  String get fundDeposit => 'Взнос';

  @override
  String get fundWithdrawal => 'Снятие';

  @override
  String get fundPerson => 'Сотрудник';

  @override
  String get fundAmountPositive => 'Введите сумму больше нуля';

  @override
  String get lunchDuty => 'Дежурство на обеде';

  @override
  String get tagLab => 'Лабораторный урок';

  @override
  String get tagAfter => 'Урок после занятий';

  @override
  String get updTitle => 'Обновления';

  @override
  String get updNothingNew => 'На этой неделе ничего нового';

  @override
  String get updJustNow => 'только что';

  @override
  String updMinutesAgo(int count) {
    return '$count мин назад';
  }

  @override
  String updHoursAgo(int count) {
    return '$count ч назад';
  }

  @override
  String get updYesterday => 'вчера';

  @override
  String updDaysAgo(int count) {
    return '$count дн назад';
  }

  @override
  String updPoints(String points) {
    return '$points баллов';
  }

  @override
  String updTakenFrom(String name) {
    return 'Снято: $name';
  }

  @override
  String updAddedTo(String name) {
    return 'Зачислено: $name';
  }

  @override
  String get updUpcomingEvent => 'Скоро';

  @override
  String get updTomorrow => 'завтра';

  @override
  String get dombitTooltip => 'Dombit \$ PDF за прошлую неделю';

  @override
  String get dombitFailed => 'Не удалось создать PDF';

  @override
  String get updates => 'Обновления';

  @override
  String get whatsNewPhotoZoomTitle => 'Нажмите на фото, чтобы увеличить';

  @override
  String get whatsNewAttendanceTitle => 'Статистика посещаемости';

  @override
  String get whatsNewAttendanceBody => 'Посещаемость по классам и ученикам';

  @override
  String get whatsNewPasskeysTitle => 'Вход с ключом доступа';

  @override
  String get whatsNewPasskeysBody => 'Вход по отпечатку пальца или лицу';

  @override
  String get whatsNewPhotoZoomBody => 'Фото профиля открываются во весь экран';

  @override
  String get whatsNewGradingTitle => 'Новая ежедневная оценка';

  @override
  String get whatsNewGradingBody => 'Пять категорий, опоздание снижает балл';

  @override
  String get myAnalysis => 'Мои анализы';

  @override
  String get tourReplay => 'Пройти тур';

  @override
  String get tourSkip => 'Пропустить';

  @override
  String get tourFinish => 'Готово';

  @override
  String tourProgress(int current, int total) {
    return '$current из $total';
  }

  @override
  String tourWelcomeTitle(String name) {
    return 'Добро пожаловать, $name!';
  }

  @override
  String get tourWelcomeBody =>
      'Короткий обзор основных разделов приложения — около минуты. Его можно пропустить и пройти снова в любое время из Профиля.';

  @override
  String get tourScheduleTitle => 'Ваш день';

  @override
  String get tourScheduleBody =>
      'Уроки и встречи на сегодня, текущий урок выделен. Нажмите, чтобы отметить посещаемость и выставить оценки.';

  @override
  String get tourUpdatesTitle => 'Обновления';

  @override
  String get tourUpdatesBody =>
      'Здесь сменяются ваши последние баллы, накопления, объявления и ближайшие события. Листайте вбок.';

  @override
  String get tourAppsTitle => 'Ваши приложения';

  @override
  String get tourAppsBody =>
      'Здесь все доступные вам приложения. Нажмите на плитку, чтобы открыть. Нажмите и удерживайте плитку, чтобы переставить; порядок сохранится.';

  @override
  String get tourNotificationsTitle => 'Уведомления';

  @override
  String get tourNotificationsBody =>
      'Здесь появляются новые сообщения и обновления для вас.';

  @override
  String get tourNavTitle => 'Быстрая навигация';

  @override
  String get tourNavBody =>
      'Основные приложения всегда под рукой внизу экрана.';

  @override
  String get tourProfileTitle => 'Ваш профиль';

  @override
  String get tourProfileBody =>
      'Настройки, язык, тема, предложения и выход. Отсюда можно пройти этот тур снова.';

  @override
  String get tourDoneTitle => 'Готово!';

  @override
  String get tourDoneBody =>
      'Это всё. Всё новое появится в карточке «Обновления» на главной.';

  @override
  String get whatsNewCalendarTitle => 'Календарь, анализы и другое';

  @override
  String get whatsNewCalendarBody =>
      'Новое на главной: Календарь, Мои анализы, Моя кафедра для руководителей и обзорный тур.';

  @override
  String get passkeySignIn => 'Войти с ключом доступа';

  @override
  String get passkeyOfferTitle => 'Входите быстрее в следующий раз';

  @override
  String get passkeyOfferBody =>
      'Добавьте ключ доступа и в следующий раз входите по Face ID, отпечатку пальца или коду телефона вместо пароля.';

  @override
  String get passkeyAdd => 'Добавить ключ доступа';

  @override
  String get passkeyNotNow => 'Не сейчас';

  @override
  String get passkeyAdded => 'Ключ доступа добавлен';

  @override
  String get passkeyAddFailed =>
      'Не удалось добавить ключ доступа. Попробуйте позже.';

  @override
  String get passkeyUnavailable =>
      'Ключи доступа пока недоступны на этом телефоне.';

  @override
  String gradedTimesThisWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Оценено $count раз на этой неделе',
      few: 'Оценено $count раза на этой неделе',
      one: 'Оценено $count раз на этой неделе',
    );
    return '$_temp0';
  }

  @override
  String get behaviorDeleteTooltip => 'Удалить запись и связанные баллы Dombit';

  @override
  String get behaviorDeleteTitle => 'Удалить запись о поведении?';

  @override
  String behaviorDeleteBody(String name) {
    return 'Это удалит запись о поведении ($name) и связанные с ней баллы Dombit. Отменить нельзя.';
  }

  @override
  String get behaviorDeleteConfirm => 'Удалить';

  @override
  String get behaviorDeleted => 'Запись о поведении удалена.';

  @override
  String behaviorDeletedWithPoints(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Запись и $count связанных записей баллов удалены.',
      few: 'Запись и $count связанные записи баллов удалены.',
      one: 'Запись и $count связанная запись баллов удалены.',
    );
    return '$_temp0';
  }

  @override
  String get behaviorDeleteFailed => 'Не удалось удалить запись.';

  @override
  String get resetGradesTitle => 'Сброс оценок';

  @override
  String get resetGradesNoActiveYear => 'Нет активного учебного года.';

  @override
  String get resetGradesSelectClasses => 'Выбрать классы';

  @override
  String get resetGradesSearchClasses => 'Поиск классов';

  @override
  String get resetGradesAllClasses => 'Все классы';

  @override
  String resetGradesClassesSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count класса',
      many: '$count классов',
      few: '$count класса',
      one: '1 класс',
    );
    return '$_temp0';
  }

  @override
  String get resetGradesGraded => 'С оценками';

  @override
  String get resetGradesAll => 'Все';

  @override
  String get resetGradesSelectAll => 'Выбрать все уроки';

  @override
  String resetGradesSelectedCount(int selected, int total) {
    return 'Выбрано: $selected из $total';
  }

  @override
  String get resetGradesNothing => 'В этот день нет уроков для сброса оценок.';

  @override
  String get resetGradesNothingGraded => 'Пока нет оценённых уроков.';

  @override
  String resetGradesGradedCount(int count) {
    return 'Оценок: $count';
  }

  @override
  String resetGradesConfirmTitle(int count, String date) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Сбросить оценки за $count урока · $date?',
      many: 'Сбросить оценки за $count уроков · $date?',
      few: 'Сбросить оценки за $count урока · $date?',
      one: 'Сбросить оценки за 1 урок · $date?',
    );
    return '$_temp0';
  }

  @override
  String get resetGradesConfirmBody =>
      'Оценки и комментарии будут удалены. Посещаемость сохранится. Действие будет записано.';

  @override
  String resetGradesCleared(int count) {
    return 'Записей с оценками очищено: $count.';
  }

  @override
  String get resetGradesFailed => 'Не удалось сбросить оценки.';

  @override
  String get resetGradesClearSelection => 'Снять выбор';

  @override
  String get resetGradesPreviousDay => 'Предыдущий день';

  @override
  String get resetGradesNextDay => 'Следующий день';

  @override
  String get laCurrentTerm => 'Текущий триместр';

  @override
  String get laTerm => 'Триместр';

  @override
  String get laObservationType => 'Тип наблюдения';

  @override
  String get laRoutine => 'Обычное';

  @override
  String get laFormal => 'Формальное';

  @override
  String get laFollowUp => 'Повторное';

  @override
  String get laCommunication => 'Коммуникация';

  @override
  String get laRecommendations => 'Рекомендации';

  @override
  String get laAction => 'План действий';

  @override
  String get laKpiPoints => 'Оценка KPI';

  @override
  String laScoreMissing(int count) {
    return 'Оцените ещё $count KPI перед сохранением.';
  }

  @override
  String get laTeacherToStudent => 'Учитель → ученик';

  @override
  String get laStudentToTeacher => 'Ученик → учитель';

  @override
  String get laStudentToStudent => 'Ученик ↔ ученик';

  @override
  String get laRecCoverage =>
      'Уделять внимание ученикам в глубине и по краям класса';

  @override
  String get laRecBalance => 'Сбалансировать общение учителя и учеников';

  @override
  String get laRecMovement => 'Перемещаться по классу';

  @override
  String get laRecQuestions => 'Задавать вопросы не только активным ученикам';

  @override
  String get laRecQuietStudents =>
      'Привлекать к ответам менее активных учеников';

  @override
  String get laRecPeerTalk => 'Использовать обсуждения в парах и группах';

  @override
  String get laRecSeating => 'Пересмотреть рассадку и состав групп';

  @override
  String get laRecRecheck => 'Повторно проверить менее вовлечённых учеников';
}
