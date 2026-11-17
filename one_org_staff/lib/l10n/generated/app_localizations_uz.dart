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
}
