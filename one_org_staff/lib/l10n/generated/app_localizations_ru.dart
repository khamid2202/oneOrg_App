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
}
