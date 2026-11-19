// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Uzbek (`uz`).
class AppLocalizationsUz extends AppLocalizations {
  AppLocalizationsUz([String locale = 'uz']) : super(locale);

  @override
  String get language => 'Til';

  @override
  String get mySchedule => 'Mening jadvalim';

  @override
  String get today => 'Bugun';

  @override
  String get retry => 'Qayta urinish';

  @override
  String get loadLessonsFailed =>
      'Darslarni yuklab bo‘lmadi. Qayta urinib ko‘ring.';

  @override
  String noLessonsOn(String date) {
    return '$date kuni darsingiz yo‘q.';
  }

  @override
  String nowFor(String duration) {
    return 'Hozir · $duration';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes daq';
  }

  @override
  String durationHours(int hours) {
    return '$hours soat';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours soat $minutes daq';
  }

  @override
  String get substitution => 'O‘rinbosarlik';

  @override
  String get cancelled => 'Bekor qilingan';

  @override
  String get meeting => 'Yig‘ilish';

  @override
  String get untitled => 'Nomsiz';

  @override
  String periodShort(int number) {
    return '$number-d';
  }

  @override
  String get noLessonRecord =>
      'Bu sanada baholash uchun dars yozuvi yo‘q: e’lon qilingan jadval boshlanishidan oldin, bayram kuni yoki hali yaratilmagan.';

  @override
  String get attendance => 'Davomat';

  @override
  String get scores => 'Baholar';

  @override
  String get present => 'Bor';

  @override
  String get late => 'Kechikdi';

  @override
  String get absent => 'Yo‘q';

  @override
  String get excused => 'Sababli';

  @override
  String get presentShort => 'B';

  @override
  String get lateShort => 'K';

  @override
  String get absentShort => 'Y';

  @override
  String get excusedShort => 'S';

  @override
  String minutesShort(int minutes) {
    return '${minutes}d';
  }

  @override
  String get minutesHint => 'daq';

  @override
  String get materials => 'Daftar';

  @override
  String get homeworkDone => 'Vazifa bor';

  @override
  String get homework => 'To\'g\'ri';

  @override
  String get activity => 'Faollik';

  @override
  String get notes => 'Konspekt';

  @override
  String get next => 'Keyingi';

  @override
  String get saveAndNext => 'Saqlash va keyingi';

  @override
  String get save => 'Saqlash';

  @override
  String get skip => 'O‘tkazib yuborish';

  @override
  String get saved => 'Saqlangan';

  @override
  String get attendanceSaved => 'Davomat saqlandi';

  @override
  String get scoresSaved => 'Baholar saqlandi';

  @override
  String studentsCount(int count) {
    return '$count o‘quvchi';
  }

  @override
  String addMinutesForLate(int count) {
    return '$count kechikkan uchun daqiqa kiriting';
  }

  @override
  String needFixing(int count) {
    return '$count tasini tuzatish kerak';
  }

  @override
  String toSave(int count) {
    return '$count ta saqlanadi';
  }

  @override
  String get fixHighlightedRows => 'Avval belgilangan qatorlarni tuzating';

  @override
  String get lessonCancelledBanner =>
      'Bu dars bekor qilingan; baholarni o‘zgartirib bo‘lmaydi.';

  @override
  String lessonCancelledReasonBanner(String reason) {
    return 'Bu dars bekor qilingan ($reason); baholarni o‘zgartirib bo‘lmaydi.';
  }

  @override
  String get windowClosedBanner =>
      'Baholarni darsdan keyin 3 kun ichida, shanba 08:00 gacha o‘zgartirish mumkin. Tuzatish uchun administratorga murojaat qiling.';

  @override
  String get noStudents => 'Bu sanada sinfda o‘quvchi yo‘q.';

  @override
  String get unsavedTitle => 'Saqlanmagan o‘zgarishlar';

  @override
  String get unsavedBody => 'O‘zgarishlarni saqlamasdan chiqasizmi?';

  @override
  String get stay => 'Qolish';

  @override
  String get leave => 'Chiqish';

  @override
  String get commentHint => 'Izoh';

  @override
  String get whyBelow40 => 'Nega 40 dan past? (majburiy)';

  @override
  String get noteOptional => 'Izoh (sabab tanlansa ixtiyoriy)';

  @override
  String get foldAll => 'Hammasini yig‘ish';

  @override
  String get unfoldAll => 'Hammasini ochish';

  @override
  String get uploads => 'Yuklashlar';

  @override
  String get tryNow => 'Hozir urinish';

  @override
  String notAccepted(String reason) {
    return 'Qabul qilinmadi: $reason';
  }

  @override
  String waitingForConnection(int tries) {
    return 'Aloqa kutilmoqda ($tries urinish)';
  }

  @override
  String get discard => 'O‘chirish';

  @override
  String get behavior => 'Xulq';

  @override
  String waitingToUpload(int count) {
    return '$count ta yuklanishi kutilmoqda';
  }

  @override
  String notAcceptedCount(int count) {
    return '$count ta qabul qilinmadi';
  }

  @override
  String signOutUnsent(int count) {
    return '$count ta saqlangan ma’lumot hali shu telefonda. Chiqsangiz, ular yo‘qoladi.';
  }

  @override
  String get home => 'Bosh sahifa';

  @override
  String get schedule => 'Jadvalim';

  @override
  String get classShort => 'Sinf';

  @override
  String get myClass => 'Mening sinfim';

  @override
  String get grades => 'Baholar';

  @override
  String get exams => 'Imtihonlar';

  @override
  String get timetable => 'Dars jadvali';

  @override
  String get rewards => 'Mukofotlar';

  @override
  String get colleagues => 'Hamkasblar';

  @override
  String get pointReport => 'Ballar hisoboti';

  @override
  String get profile => 'Profil';

  @override
  String hiName(String name) {
    return 'Salom, $name';
  }

  @override
  String lessonsExamsCount(int lessons, int exams) {
    return 'Darslar: $lessons · Imtihonlar: $exams';
  }

  @override
  String get loadFailed => 'Yuklab boʻlmadi. Internetni tekshiring.';

  @override
  String get noClassesYet => 'Sizga hali sinf biriktirilmagan.';

  @override
  String get noGradesYet => 'Hali baholar yoʻq.';

  @override
  String get all => 'Hammasi';

  @override
  String get student => 'Oʻquvchi';

  @override
  String get averageShort => 'Oʻrt';

  @override
  String get examsShort => 'Imt.';

  @override
  String get reportStudent => 'Oʻquvchi hisoboti';

  @override
  String get reportShort => 'Hisobot';

  @override
  String get markTab => 'Belgilash';

  @override
  String get historyTab => 'Tarix';

  @override
  String get statisticsTab => 'Statistika';

  @override
  String get stepWho => 'Kim';

  @override
  String get stepWhatKind => 'Qanday';

  @override
  String get stepWhy => 'Nima uchun';

  @override
  String get searchAnyStudent => 'Istalgan oʻquvchini qidiring…';

  @override
  String get otherClass => 'Boshqa sinf…';

  @override
  String get mine => 'meniki';

  @override
  String get selectAll => 'Hammasini tanlash';

  @override
  String get unselectAll => 'Tanlovni bekor qilish';

  @override
  String get tapStudentsFirst => 'Avval oʻquvchilarni tanlang';

  @override
  String nextWho(String who) {
    return 'Keyingi · $who';
  }

  @override
  String get pickOneAbove => 'Yuqoridan birini tanlang';

  @override
  String get pickReasonOrComment => 'Sabab tanlang yoki izoh yozing';

  @override
  String saveForWho(String who) {
    return '$who uchun saqlash';
  }

  @override
  String savedForWho(String who) {
    return '$who uchun saqlandi';
  }

  @override
  String get seeInHistory => 'Tarixda koʻrish';

  @override
  String get markMore => 'Yana belgilash';

  @override
  String markMoreIn(String cls) {
    return '$cls sinfida yana belgilash';
  }

  @override
  String get back => 'Orqaga';

  @override
  String get positive => 'Ijobiy';

  @override
  String get needsAttention => 'Eʼtibor kerak';

  @override
  String get positiveDetail => 'Maqtovga loyiq ish';

  @override
  String get negativeDetail => 'Ustida ishlash kerak boʻlgan narsa';

  @override
  String get addCommentOptional => 'Izoh qoʻshing (ixtiyoriy)';

  @override
  String get noStudentNamed => 'Bunday ismli oʻquvchi yoʻq.';

  @override
  String get noStudentsInClass => 'Bu sinfda oʻquvchilar yoʻq.';

  @override
  String get loadingStudents => 'Oʻquvchilar yuklanmoqda…';

  @override
  String acrossSchool(int count) {
    return 'Maktab boʻyicha $count ta';
  }

  @override
  String get studentOrClass => 'Oʻquvchi yoki sinf';

  @override
  String get noFilterMatches => 'Bu filtrlarga mos narsa yoʻq.';

  @override
  String get noBehaviorMarks => 'Hali xulq belgilari yoʻq.';

  @override
  String get from => 'Dan';

  @override
  String get to => 'Gacha';

  @override
  String get total => 'Jami';

  @override
  String get byClass => 'Sinflar boʻyicha';

  @override
  String get byWeek => 'Haftalar boʻyicha';

  @override
  String get commonReasons => 'Koʻp uchraydigan sabablar';

  @override
  String get noMarksForPeriod => 'Bu davr uchun belgilar yoʻq.';

  @override
  String get myPlan => 'Mening rejam';

  @override
  String get myPoints => 'Mening ballarim';

  @override
  String get myFundings => 'Mening jamg‘armam';

  @override
  String get teachingTools => 'Dars vositalari';

  @override
  String get teachingShort => 'Dars';

  @override
  String get thisMonth => 'Shu oy';

  @override
  String get last30Days => 'Oxirgi 30 kun';

  @override
  String get thisYear => 'Shu yil';

  @override
  String get moreFilters => 'Boshqa filtrlar';

  @override
  String get allCategories => 'Barcha toifalar';

  @override
  String historyCount(int count) {
    return 'Tarix ($count)';
  }

  @override
  String inThisPeriod(String amount) {
    return 'Shu davrda $amount';
  }

  @override
  String get noPointsYet =>
      'Sizga berilgan yoki olib tashlangan ballar shu yerda ko‘rinadi.';

  @override
  String get nothingInPeriod => 'Bu davrda hech narsa yo‘q.';

  @override
  String get noSavingsYet => 'Jamg‘armangiz shu yerda ko‘rinadi.';

  @override
  String get showAmounts => 'Summalarni ko‘rsatish';

  @override
  String get hideAmounts => 'Summalarni yashirish';

  @override
  String get currencySom => 'so‘m';

  @override
  String get received => 'Kirim';

  @override
  String get withdrawn => 'Chiqim';

  @override
  String get balance => 'Qoldiq';

  @override
  String get addMilestone => 'Bosqich qo‘shish';

  @override
  String get editMilestone => 'Bosqichni tahrirlash';

  @override
  String get milestones => 'Bosqichlar';

  @override
  String get noPlanYet =>
      'Hali reja yo‘q. Yilni bosqichlarga bo‘ling va bajarganingizni belgilab boring.';

  @override
  String get noMilestonesWithStatus => 'Bu holatda hech narsa yo‘q.';

  @override
  String get planNotStarted => 'Boshlanmagan';

  @override
  String get planInProgress => 'Jarayonda';

  @override
  String get planDone => 'Bajarildi';

  @override
  String get planPostponed => 'Qoldirildi';

  @override
  String get planCancelled => 'Bekor qilindi';

  @override
  String get overdue => 'Muddati o‘tgan';

  @override
  String get priority => 'Muhimlik';

  @override
  String get priorityLow => 'Past';

  @override
  String get priorityMedium => 'O‘rtacha';

  @override
  String get priorityHigh => 'Yuqori';

  @override
  String get priorityUrgent => 'Shoshilinch';

  @override
  String get status => 'Holat';

  @override
  String get category => 'Toifa';

  @override
  String get categoryCurriculum => 'O‘quv dasturi';

  @override
  String get categoryLesson => 'Dars';

  @override
  String get categoryExam => 'Imtihon';

  @override
  String get categoryMeeting => 'Yig‘ilish';

  @override
  String get categoryAdministrative => 'Ma’muriy';

  @override
  String get categoryPersonal => 'Shaxsiy';

  @override
  String get categoryGeneral => 'Umumiy';

  @override
  String get starts => 'Boshlanishi';

  @override
  String get ends => 'Tugashi';

  @override
  String get milestoneTitleHint => 'Sarlavha, masalan: 1-chorak algebra';

  @override
  String get addFiles => 'Fayl qo‘shish';

  @override
  String fileTooBig(String name) {
    return '$name hajmi 10 MB dan katta';
  }

  @override
  String get milestoneNeedsTitle => 'Bosqichga sarlavha bering';

  @override
  String get endBeforeStart =>
      'Tugash sanasi boshlanishidan oldin bo‘lishi mumkin emas';

  @override
  String get milestoneAdded => 'Bosqich qo‘shildi';

  @override
  String get milestoneUpdated => 'Bosqich yangilandi';

  @override
  String get milestoneDeleted => 'Bosqich o‘chirildi';

  @override
  String get couldNotSaveMilestone => 'Bosqichni saqlab bo‘lmadi';

  @override
  String get couldNotDeleteMilestone => 'Bosqichni o‘chirib bo‘lmadi';

  @override
  String get planStatusFailed => 'Holatni yangilab bo‘lmadi';

  @override
  String get deleteMilestoneTitle => 'Bu bosqich o‘chirilsinmi?';

  @override
  String deleteMilestoneBody(String agenda) {
    return '\"$agenda\" va uning fayllari o‘chiriladi. Buni qaytarib bo‘lmaydi.';
  }

  @override
  String get cancel => 'Bekor qilish';

  @override
  String get delete => 'O‘chirish';

  @override
  String get soon => 'Tez orada';

  @override
  String get teamShuffle => 'Jamoalarga bo‘lish';

  @override
  String get namePicker => 'Ism tanlash';

  @override
  String get timer => 'Taymer';

  @override
  String get participation => 'Faollik';

  @override
  String get homeworkCheck => 'Uy vazifasi';

  @override
  String get balancedTeams => 'Teng jamoalar';

  @override
  String get seatingPlan => 'O‘tirish rejasi';

  @override
  String get done => 'Tayyor';

  @override
  String get absentQuestion => 'Kim yo‘q?';

  @override
  String get startOver => 'Qaytadan';

  @override
  String get fewerTeams => 'Kamroq jamoa';

  @override
  String get moreTeams => 'Ko‘proq jamoa';

  @override
  String get roles => 'Rollar';

  @override
  String get shuffle => 'Bo‘lish';

  @override
  String get again => 'Yana';

  @override
  String get teamRed => 'Qizil';

  @override
  String get teamBlue => 'Ko‘k';

  @override
  String get teamGreen => 'Yashil';

  @override
  String get teamYellow => 'Sariq';

  @override
  String get teamPurple => 'Binafsha';

  @override
  String get teamOrange => 'To‘q sariq';

  @override
  String get teamPink => 'Pushti';

  @override
  String get teamTeal => 'Moviy';

  @override
  String get roleLeader => 'Sardor';

  @override
  String get roleTimekeeper => 'Vaqt nazoratchisi';

  @override
  String get roleRecorder => 'Kotib';

  @override
  String get roleReporter => 'Taqdimotchi';

  @override
  String get roleChecker => 'Tekshiruvchi';

  @override
  String get roleEncourager => 'Ruhlantiruvchi';

  @override
  String get roleMaterials => 'Materiallar';

  @override
  String get roleQuestioner => 'Savol beruvchi';

  @override
  String get roleHelper => 'Yordamchi';

  @override
  String get oneMinuteLess => 'Bir daqiqa kam';

  @override
  String get oneMinuteMore => 'Bir daqiqa ko‘p';

  @override
  String get pause => 'Pauza';

  @override
  String get start => 'Boshlash';

  @override
  String get reset => 'Qayta o‘rnatish';

  @override
  String get comingSoon => 'Tez orada';

  @override
  String get comingSoonBody => 'Ilovaning bu qismi hali tayyor emas.';

  @override
  String get search => 'Qidirish';

  @override
  String get notifications => 'Bildirishnomalar';

  @override
  String get searchHint => 'Sahifalar, o‘quvchilar, kodlar…';

  @override
  String get searchPagesHint => 'Ilovadan qidirish…';

  @override
  String get searchSuggested => 'Tavsiya';

  @override
  String get searchPages => 'Sahifalar';

  @override
  String get searchPeople => 'Odamlar';

  @override
  String searchFound(int count) {
    return '$count ta topildi';
  }

  @override
  String searchMinChars(int count) {
    return 'Odamlarni qidirish uchun $count ta harf yozing';
  }

  @override
  String searchNothing(String query) {
    return '“$query” bo‘yicha hech narsa topilmadi';
  }

  @override
  String get searchNothingBody =>
      'Boshqacha yozib ko‘ring, o‘quvchi kodi yoki sahifa nomini kiriting.';

  @override
  String get searchNothingPagesBody =>
      'Sahifa uchun boshqa so‘z yozib ko‘ring.';

  @override
  String get searchShowMore => 'Yana ko‘rsatish';

  @override
  String get searchLeft => 'Ketgan';

  @override
  String searchGrade(int grade) {
    return '$grade-sinf';
  }

  @override
  String get searchFailed => 'Odamlarni qidirib bo‘lmadi.';

  @override
  String colleaguesActive(int count) {
    return '$count ta faol hamkasb';
  }

  @override
  String get colleaguesNone => 'Hamkasblar topilmadi.';

  @override
  String get colleaguesNoneMatching => 'Qidiruv bo‘yicha hamkasb topilmadi.';

  @override
  String get colleaguesNoPhone => 'Telefon raqami yo‘q';

  @override
  String colleaguesCall(String name) {
    return '${name}ga qo‘ng‘iroq';
  }

  @override
  String colleaguesMessage(String name) {
    return '${name}ga SMS';
  }

  @override
  String get colleaguesCopied => 'Raqam nusxalandi';

  @override
  String get colleaguesCantCall => 'Telefon ilovasini ochib bo‘lmadi.';

  @override
  String get colleaguesLoadFailed => 'Hamkasblarni yuklab bo‘lmadi.';

  @override
  String get clearSearch => 'Qidiruvni tozalash';

  @override
  String get resetFilters => 'Filtrlarni tozalash';

  @override
  String pointsFor(String date) {
    return '$date uchun';
  }

  @override
  String get pointsEdited => 'tahrirlangan';

  @override
  String get pointsRefreshFailed => 'Ballarni yangilab bo‘lmadi.';

  @override
  String get pointsWiderPeriod => 'Kengroq davrni tanlang.';

  @override
  String get colleaguesSwipeCall => 'Qo‘ng‘iroq';

  @override
  String get colleaguesSwipeMessage => 'Xabar';

  @override
  String get classStudentsTab => 'O‘quvchilar';

  @override
  String get classGradesTab => 'Baholar';

  @override
  String get classBehaviorTab => 'Xulq';

  @override
  String classStudentCount(int count) {
    return '$count o‘quvchi';
  }

  @override
  String get classLeft => 'Ketgan';

  @override
  String get classPresent => 'O‘qiydi';

  @override
  String get classContacts => 'Kontaktlar';

  @override
  String get classNoContacts => 'Hali kontaktlar yo‘q.';

  @override
  String get classEditContacts => 'Kontaktlarni tahrirlash';

  @override
  String get classNoStudents => 'Bu sinfda o‘quvchilar yo‘q.';

  @override
  String get classNoHomeroom => 'Sinf biriktirilmagan';

  @override
  String get classNoHomeroomBody =>
      'Bu yil siz hech bir sinfning sinf rahbari emassiz.';

  @override
  String get classGradesNone => 'Hali baholar yo‘q';

  @override
  String get classGradesFailed => 'Baholarni yuklab bo‘lmadi.';

  @override
  String get classDaily => 'Kunlik';

  @override
  String get classGraded => 'Baholangan';

  @override
  String get classCatAttend => 'Davomat';

  @override
  String get classCatBooks => 'Kitob';

  @override
  String get classCatHomework => 'UV';

  @override
  String get classCatActive => 'Faollik';

  @override
  String get classCatNotes => 'Daftar';

  @override
  String get classBehaviorFailed => 'Xulqni yuklab bo‘lmadi.';

  @override
  String get classPositive => 'Ijobiy';

  @override
  String get classNeedsAttention => 'E’tibor kerak';

  @override
  String get classMark => 'Belgilash';

  @override
  String get classNoMarks => 'Hali belgilar yo‘q';

  @override
  String classAllMarks(int count) {
    return 'Hammasi: $count';
  }

  @override
  String notMarkedCount(int count) {
    return '$count ta belgilanmagan';
  }

  @override
  String get allMarked => 'Hammasi belgilandi';

  @override
  String get notMarked => 'belgilanmagan';

  @override
  String notFinished(int count) {
    return '$count ta tugallanmagan';
  }

  @override
  String scoreEveryCategory(int count) {
    return 'Avval $count ta oʻquvchining barcha toifalarini baholang';
  }

  @override
  String get oldGradingLesson =>
      'bu dars yangi baholashdan oldin belgilangan, shuning uchun eski toifalar ishlaydi';

  @override
  String get profileAccount => 'Hisob';

  @override
  String get profileApp => 'Ilova';

  @override
  String get profileEmail => 'Email';

  @override
  String get profilePhone => 'Telefon';

  @override
  String get profilePassword => 'Parol';

  @override
  String get profileSystem => 'Tizim';

  @override
  String get profileSystemHint => 'Til, rang, tungi rejim';

  @override
  String get profileSuggestions => 'Takliflar';

  @override
  String get profileLogOut => 'Chiqish';

  @override
  String get profileNotSet => 'Kiritilmagan';

  @override
  String get profileContactTitle => 'Aloqa ma\'lumotlari';

  @override
  String get profileInvalidEmail => 'To\'g\'ri email kiriting';

  @override
  String get profileInvalidPhone => 'To\'g\'ri telefon raqam kiriting';

  @override
  String get profileContactSaved => 'Aloqa ma\'lumotlari yangilandi';

  @override
  String get profileContactFailed => 'Aloqa ma\'lumotlarini yangilab bo\'lmadi';

  @override
  String get suggestionsLead =>
      'G\'oyalar, muammolar, savollar — har birini o\'qiymiz.';

  @override
  String get suggestionsPrompt => 'Nimani yaxshilashimiz kerak?';

  @override
  String get suggestionsHint => 'Taklifingizni yozing…';

  @override
  String get suggestionsAnonymous => 'Anonim';

  @override
  String get suggestionsSend => 'Yuborish';

  @override
  String get suggestionsSentButton => 'Yuborildi';

  @override
  String get suggestionsSent => 'Yuborildi — rahmat!';

  @override
  String get suggestionsFailed => 'Yuborib bo\'lmadi. Qayta urinib ko\'ring.';

  @override
  String get edit => 'Tahrirlash';

  @override
  String get calendar => 'Kalendar';

  @override
  String get calToday => 'Bugun';

  @override
  String get calNewEvent => 'Yangi tadbir';

  @override
  String get calEditEvent => 'Tadbirni tahrirlash';

  @override
  String get calEvents => 'Tadbirlar';

  @override
  String get calHolidays => 'Bayramlar';

  @override
  String get calTerms => 'Choraklar';

  @override
  String get calExams => 'Imtihonlar';

  @override
  String get calAllEvents => 'Barcha tadbirlar';

  @override
  String get calNothingOnDay => 'Bu kunda hech narsa yo\'q';

  @override
  String get calEvent => 'Tadbir';

  @override
  String get calHoliday => 'Bayram';

  @override
  String get calTermStarts => 'Chorak boshlanadi';

  @override
  String get calTermEnds => 'Chorak tugaydi';

  @override
  String get calExamPeriod => 'Imtihon davri';

  @override
  String get calAllDay => 'Kun bo\'yi';

  @override
  String get calCancelled => 'Bekor qilingan';

  @override
  String get calDraft => 'Qoralama';

  @override
  String get calCancelEvent => 'Tadbirni bekor qilish';

  @override
  String get calCancelEventQ => 'Tadbir bekor qilinsinmi?';

  @override
  String get calDeleteEventQ => 'Tadbir o\'chirilsinmi?';

  @override
  String get calEventCancelled => 'Tadbir bekor qilindi';

  @override
  String get calEventDeleted => 'Tadbir o\'chirildi';

  @override
  String get calChangeFailed => 'O\'zgarishni saqlab bo\'lmadi';

  @override
  String get calTitle => 'Nomi';

  @override
  String get calTitleRequired => 'Nomini kiriting';

  @override
  String get calCategory => 'Turkum';

  @override
  String get calLocation => 'Joy';

  @override
  String get calDescription => 'Tavsif';

  @override
  String get calAudience => 'Kimlar ko\'radi';

  @override
  String get calAddAudience => 'Qo\'shish';

  @override
  String get calAllStaff => 'Barcha xodimlar';

  @override
  String get calAllStudents => 'Barcha o\'quvchilar';

  @override
  String get calGrade => 'Sinf darajasi';

  @override
  String get calClass => 'Sinf';

  @override
  String get calRole => 'Rol';

  @override
  String get calDepartment => 'Kafedra';

  @override
  String get calSaveAsDraft => 'Qoralama sifatida saqlash';

  @override
  String get calNotify => 'Bildirishnoma yuborish';

  @override
  String get calCatGeneral => 'Umumiy';

  @override
  String get calCatCeremony => 'Marosim';

  @override
  String get calCatParentMeeting => 'Ota-onalar yig\'ilishi';

  @override
  String get calCatTrip => 'Sayohat';

  @override
  String get calCatSports => 'Sport';

  @override
  String get calCatCompetition => 'Musobaqa';

  @override
  String get calCatDeadline => 'Muddat';

  @override
  String get calCatStaff => 'Xodimlar';

  @override
  String get calCatOther => 'Boshqa';

  @override
  String get myLessonAnalysis => 'Dars tahlili natijalari';

  @override
  String get myAnalysisShort => 'Tahlilim';

  @override
  String get lessonAnalysis => 'Dars tahlili';

  @override
  String get laNoneYet =>
      'Hozircha tahlil yo\'q. Darsingiz tahlil qilinganda natijalar shu yerda chiqadi.';

  @override
  String get laTotalPoints => 'Jami ballar';

  @override
  String get laThisMonth => 'Shu oy';

  @override
  String get laLastMonth => 'O\'tgan oy';

  @override
  String get laAllTime => 'Butun vaqt';

  @override
  String get laAnalyses => 'Tahlillar';

  @override
  String get laLatest => 'Oxirgisi';

  @override
  String laNotesCount(int count) {
    return '$count ta izoh';
  }

  @override
  String get laNoNotes => 'Izoh yo\'q';

  @override
  String get laMyDepartment => 'Kafedram';

  @override
  String laAnalysedOf(int analysed, int total) {
    return '$total o\'qituvchidan $analysed tasi tahlil qilingan';
  }

  @override
  String laAnalysesCount(int count) {
    return '$count ta tahlil';
  }

  @override
  String get laNotAnalysed => 'Hali tahlil qilinmagan';

  @override
  String get laSortLast => 'Oxirgi tahlil';

  @override
  String get laSortMost => 'Eng ko\'p ball';

  @override
  String get laSortLeast => 'Eng kam ball';

  @override
  String get laSortName => 'Ism';

  @override
  String get laNewAnalysis => 'Yangi tahlil';

  @override
  String get laEditAnalysis => 'Tahlilni tahrirlash';

  @override
  String get laDeleteQ => 'Tahlil o\'chirilsinmi?';

  @override
  String get laDeleteBody => 'Uning ballari o\'qituvchidan qaytarib olinadi.';

  @override
  String get laDeleted => 'Tahlil o\'chirildi';

  @override
  String get laTeacher => 'O\'qituvchi';

  @override
  String get laLesson => 'Dars';

  @override
  String get laNoLessons => 'So\'nggi 60 kunda tahlil qilinadigan dars yo\'q.';

  @override
  String get laAnalysed => 'tahlil qilingan';

  @override
  String get laPoints => 'Ballar';

  @override
  String get laNotes => 'Izohlar';

  @override
  String get laChooseTeacher => 'O\'qituvchini tanlang';

  @override
  String get laChooseLesson => 'Darsni tanlang';

  @override
  String get laPointsWhole => 'Ball butun son bo\'lishi kerak';

  @override
  String get laSaved => 'Saqlandi';

  @override
  String get laSaveFailed => 'Tahlilni saqlab bo\'lmadi';

  @override
  String get myDepartment => 'Kafedram';

  @override
  String get deptNone => 'Siz kafedra rahbari emassiz.';

  @override
  String get deptHead => 'Rahbar';

  @override
  String get deptDeputy => 'O\'rinbosar';

  @override
  String deptCounts(int subjects, int members) {
    return '$subjects ta fan · $members ta a\'zo';
  }

  @override
  String get deptLessons => 'Darslar';

  @override
  String get deptAttendanceTaken => 'Davomat olingan';

  @override
  String get deptGradesEntered => 'Baholar kiritilgan';

  @override
  String get deptGrades => 'Baholar';

  @override
  String get deptAvgGrade => 'O\'rtacha baho';

  @override
  String get deptAttendance => 'Davomat';

  @override
  String get deptExamAvg => 'Imtihon o\'rtachasi';

  @override
  String get deptKpi => 'KPI';

  @override
  String get deptTeachers => 'O\'qituvchilar';

  @override
  String get deptSubjects => 'Fanlar';

  @override
  String get deptClasses => 'Sinflar';

  @override
  String get deptAllClasses => 'Barcha sinflar';

  @override
  String get cashier => 'Kassa';

  @override
  String get cashReview => 'Sababsiz xulq belgilari';

  @override
  String get cashSync => 'Baholarni sinxronlash';

  @override
  String get cashSyncFailed => 'Sinxronlab bo\'lmadi';

  @override
  String cashSyncedThrough(String date) {
    return '$date gacha sinxronlangan';
  }

  @override
  String get cashClasses => 'Sinflar';

  @override
  String get cashRanking => 'Maktab reytingi';

  @override
  String get cashSearch => 'O\'quvchi ismi';

  @override
  String get cashAmount => 'Miqdor';

  @override
  String get cashNote => 'Izoh';

  @override
  String get cashSpend => 'Sarflash';

  @override
  String get cashAdd => 'Qo\'shish';

  @override
  String get cashResetQ => 'Balans \$0 ga tushirilsinmi?';

  @override
  String get cashResetZero => '\$0 ga tushirish';

  @override
  String get cashHistory => 'Tarix';

  @override
  String get cashNoHistory => 'Hali tarix yo\'q';

  @override
  String get attendanceCheck => 'Davomat';

  @override
  String get attNotMarked => 'Belgilanmagan';

  @override
  String get attOnNow => 'Hozir';

  @override
  String get attMarked => 'Belgilangan';

  @override
  String get attLater => 'Keyinroq';

  @override
  String get attNoStudents => 'O\'quvchi yo\'q';

  @override
  String get attOnlyMissing => 'Faqat belgilanmagan darsli sinflar';

  @override
  String get attNoLessons => 'Bu kunda dars yo\'q';

  @override
  String get attAbsent => 'Kelmagan';

  @override
  String get attLate => 'Kechikkan';

  @override
  String get substitutions => 'Almashtirish';

  @override
  String get subNewAbsence => 'Yangi yo\'qlik';

  @override
  String get subNone => 'Bu ikki haftada almashtirish yo\'q';

  @override
  String get subNoLessonsYet =>
      'Hali dars belgilanmagan — darslarni almashtirish uchun yo\'qlikni bosing.';

  @override
  String subLessonsCount(int count) {
    return '$count ta dars';
  }

  @override
  String get subRemove => 'Olib tashlash';

  @override
  String get subRemoveQ => 'Almashtirish olib tashlansinmi?';

  @override
  String subRemoveBody(String lesson, String time) {
    return '$time dagi $lesson asl o\'qituvchisiga qaytadi. Hech kimga xabar berilmaydi.';
  }

  @override
  String get subRemoved => 'Almashtirish olib tashlandi';

  @override
  String get subCover => 'Almashtirish';

  @override
  String get subMerge => 'Birlashtirish';

  @override
  String get subCancel => 'Bekor qilish';

  @override
  String get subNext => 'Keyingi';

  @override
  String get subReasonSick => 'Kasal';

  @override
  String get subReasonPersonal => 'Shaxsiy';

  @override
  String get subReasonTrip => 'Xizmat safari';

  @override
  String get subReasonTraining => 'O\'quv';

  @override
  String subCoverFor(String name) {
    return '$name o\'rniga';
  }

  @override
  String get subNoAffected => 'Bu yo\'qlikda dars yo\'q.';

  @override
  String get subArranged => 'Allaqachon belgilangan';

  @override
  String get subPickEach => 'Har biriga o\'rinbosar yoki dars tanlang';

  @override
  String get subSaved => 'Almashtirishlar saqlandi';

  @override
  String get subBusy => 'band';

  @override
  String get subAbsent => 'yo\'q';

  @override
  String get subUnavailable => 'mavjud emas';

  @override
  String get subSubject => 'fan';

  @override
  String get subKnowsClass => 'sinfni biladi';

  @override
  String subCoversMonth(int count) {
    return 'oyiga $count ta';
  }

  @override
  String get subSubstitute => 'O\'rinbosar';

  @override
  String get subMergeWith => 'Qaysi dars bilan';

  @override
  String get subAssignAnyway => 'Baribir tayinlash';

  @override
  String get staffPoints => 'Xodim ballari';

  @override
  String get spAward => 'Ball berish';

  @override
  String get spAwardShort => 'Berish';

  @override
  String get spDeduct => 'Ayirish';

  @override
  String get spThisWeek => 'Shu hafta';

  @override
  String get spThisYear => 'Shu yil';

  @override
  String get spChooseRecipients => 'Kimga ekanini tanlang';

  @override
  String get spAllTeachers => 'Barcha o\'qituvchilar';

  @override
  String get spNoCategory => 'Turkumsiz';

  @override
  String get spNoteRequired => 'Izoh yozing';

  @override
  String spSaved(int count) {
    return '$count kishiga saqlandi';
  }

  @override
  String spSomeFailed(int count) {
    return '$count tasini saqlab bo\'lmadi';
  }

  @override
  String get fundings => 'Jamg\'armalar';

  @override
  String get fundNew => 'Yangi yozuv';

  @override
  String get fundNone => 'Hali jamg\'arma yo\'q';

  @override
  String get fundDeposits => 'Kirimlar';

  @override
  String get fundWithdrawals => 'Chiqimlar';

  @override
  String get fundBalance => 'Balans';

  @override
  String get fundDeposit => 'Kirim';

  @override
  String get fundWithdrawal => 'Chiqim';

  @override
  String get fundPerson => 'Xodim';

  @override
  String get fundAmountPositive => 'Noldan katta miqdor kiriting';

  @override
  String get lunchDuty => 'Tushlik navbatchiligi';

  @override
  String get tagLab => 'Laboratoriya darsi';

  @override
  String get tagAfter => 'Darsdan keyingi dars';

  @override
  String get updTitle => 'Yangiliklar';

  @override
  String get updNothingNew => 'Bu hafta yangilik yo‘q';

  @override
  String get updJustNow => 'hozirgina';

  @override
  String updMinutesAgo(int count) {
    return '$count daqiqa oldin';
  }

  @override
  String updHoursAgo(int count) {
    return '$count soat oldin';
  }

  @override
  String get updYesterday => 'kecha';

  @override
  String updDaysAgo(int count) {
    return '$count kun oldin';
  }

  @override
  String updPoints(String points) {
    return '$points ball';
  }

  @override
  String updTakenFrom(String name) {
    return '$name dan olindi';
  }

  @override
  String updAddedTo(String name) {
    return '$name ga qo‘shildi';
  }

  @override
  String get updUpcomingEvent => 'Yaqinda';

  @override
  String get updTomorrow => 'ertaga';

  @override
  String get dombitTooltip => 'O‘tgan hafta uchun Dombit \$ PDF';

  @override
  String get dombitFailed => 'PDF tayyorlab bo‘lmadi';

  @override
  String get updates => 'Yangiliklar';

  @override
  String get whatsNewPhotoZoomTitle => 'Kattalashtirish uchun rasmga bosing';

  @override
  String get whatsNewPhotoZoomBody => 'Profil rasmlari toʻliq ochiladi';

  @override
  String get whatsNewGradingTitle => 'Yangi kundalik baholash';

  @override
  String get whatsNewGradingBody => 'Besh toifa, kechikish ball ayiradi';

  @override
  String get myAnalysis => 'Tahlillarim';

  @override
  String get tourReplay => 'Turni ko\'rish';

  @override
  String get tourSkip => 'O\'tkazib yuborish';

  @override
  String get tourFinish => 'Tugatish';

  @override
  String tourProgress(int current, int total) {
    return '$current / $total';
  }

  @override
  String tourWelcomeTitle(String name) {
    return 'Xush kelibsiz, $name!';
  }

  @override
  String get tourWelcomeBody =>
      'Ilovaning asosiy bo\'limlari bilan bir daqiqalik tanishuv. Uni o\'tkazib yuborib, istalgan vaqtda Profildan qayta ko\'rishingiz mumkin.';

  @override
  String get tourScheduleTitle => 'Kuningiz bir qarashda';

  @override
  String get tourScheduleBody =>
      'Bugungi darslar va yig\'ilishlar, hozirgi dars ajratib ko\'rsatilgan. Davomat va baholash uchun bosing.';

  @override
  String get tourUpdatesTitle => 'Yangiliklar';

  @override
  String get tourUpdatesBody =>
      'So\'nggi ballaringiz, jamg\'armalar, e\'lonlar va yaqin tadbirlar shu yerda almashib turadi. Varaqlash uchun yon tomonga suring.';

  @override
  String get tourAppsTitle => 'Ilovalaringiz';

  @override
  String get tourAppsBody =>
      'Sizga ochiq barcha ilovalar shu yerda. Ochish uchun plitkani bosing. Tartibini o\'zgartirish uchun plitkani bosib turing; tartib saqlanadi.';

  @override
  String get tourNotificationsTitle => 'Bildirishnomalar';

  @override
  String get tourNotificationsBody =>
      'Sizga kelgan yangi xabarlar va yangiliklar shu yerda.';

  @override
  String get tourNavTitle => 'Tez o\'tish';

  @override
  String get tourNavBody => 'Asosiy ilovalar doim ekran pastida, bir bosishda.';

  @override
  String get tourProfileTitle => 'Profilingiz';

  @override
  String get tourProfileBody =>
      'Sozlamalar, til, mavzu, takliflar va chiqish. Bu turni shu yerdan qayta ko\'rishingiz mumkin.';

  @override
  String get tourDoneTitle => 'Hammasi tayyor!';

  @override
  String get tourDoneBody =>
      'Tur shu bilan tugadi. Yangiliklar bosh sahifadagi Yangiliklar kartasida chiqadi.';

  @override
  String get whatsNewCalendarTitle => 'Taqvim, tahlillar va boshqalar';

  @override
  String get whatsNewCalendarBody =>
      'Bosh sahifada yangi: Taqvim, Tahlillarim, rahbarlar uchun Kafedram va tanishuv turi.';

  @override
  String get passkeySignIn => 'Passkey bilan kirish';

  @override
  String get passkeyOfferTitle => 'Keyingi safar tezroq kiring';

  @override
  String get passkeyOfferBody =>
      'Passkey qoʻshing va keyingi safar parol kiritmasdan Face ID, barmoq izi yoki telefon kodi bilan kiring.';

  @override
  String get passkeyAdd => 'Passkey qoʻshish';

  @override
  String get passkeyNotNow => 'Hozir emas';

  @override
  String get passkeyAdded => 'Passkey qoʻshildi';

  @override
  String get passkeyAddFailed =>
      'Passkey qoʻshib boʻlmadi. Keyinroq qayta urinib koʻring.';

  @override
  String get passkeyUnavailable => 'Bu telefonda passkey hozircha ishlamaydi.';
}
