import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_uz.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ru'),
    Locale('uz'),
  ];

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @mySchedule.
  ///
  /// In en, this message translates to:
  /// **'My Schedule'**
  String get mySchedule;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loadLessonsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to fetch lessons. Please try again.'**
  String get loadLessonsFailed;

  /// No description provided for @noLessonsOn.
  ///
  /// In en, this message translates to:
  /// **'You have no lessons on {date}.'**
  String noLessonsOn(String date);

  /// No description provided for @nowFor.
  ///
  /// In en, this message translates to:
  /// **'Now · {duration}'**
  String nowFor(String duration);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String durationMinutes(int minutes);

  /// No description provided for @durationHours.
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String durationHours(int hours);

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours}h {minutes}m'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @substitution.
  ///
  /// In en, this message translates to:
  /// **'Substitution'**
  String get substitution;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @meeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get meeting;

  /// No description provided for @untitled.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitled;

  /// No description provided for @periodShort.
  ///
  /// In en, this message translates to:
  /// **'P{number}'**
  String periodShort(int number);

  /// No description provided for @noLessonRecord.
  ///
  /// In en, this message translates to:
  /// **'This date has no lesson record to score: it\'s before the published timetable\'s start date, a holiday, or not generated yet.'**
  String get noLessonRecord;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @scores.
  ///
  /// In en, this message translates to:
  /// **'Scores'**
  String get scores;

  /// No description provided for @present.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get present;

  /// No description provided for @late.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get late;

  /// No description provided for @absent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get absent;

  /// No description provided for @excused.
  ///
  /// In en, this message translates to:
  /// **'Excused'**
  String get excused;

  /// No description provided for @presentShort.
  ///
  /// In en, this message translates to:
  /// **'P'**
  String get presentShort;

  /// No description provided for @lateShort.
  ///
  /// In en, this message translates to:
  /// **'L'**
  String get lateShort;

  /// No description provided for @absentShort.
  ///
  /// In en, this message translates to:
  /// **'A'**
  String get absentShort;

  /// No description provided for @excusedShort.
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get excusedShort;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String minutesShort(int minutes);

  /// No description provided for @minutesHint.
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get minutesHint;

  /// No description provided for @materials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get materials;

  /// No description provided for @homeworkDone.
  ///
  /// In en, this message translates to:
  /// **'HW done'**
  String get homeworkDone;

  /// No description provided for @homework.
  ///
  /// In en, this message translates to:
  /// **'HW right'**
  String get homework;

  /// No description provided for @activity.
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get activity;

  /// No description provided for @notes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @saveAndNext.
  ///
  /// In en, this message translates to:
  /// **'Save & next'**
  String get saveAndNext;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @attendanceSaved.
  ///
  /// In en, this message translates to:
  /// **'Attendance saved'**
  String get attendanceSaved;

  /// No description provided for @scoresSaved.
  ///
  /// In en, this message translates to:
  /// **'Scores saved'**
  String get scoresSaved;

  /// No description provided for @studentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} students'**
  String studentsCount(int count);

  /// No description provided for @addMinutesForLate.
  ///
  /// In en, this message translates to:
  /// **'Add minutes for {count} late'**
  String addMinutesForLate(int count);

  /// No description provided for @needFixing.
  ///
  /// In en, this message translates to:
  /// **'{count} need fixing'**
  String needFixing(int count);

  /// No description provided for @toSave.
  ///
  /// In en, this message translates to:
  /// **'{count} to save'**
  String toSave(int count);

  /// No description provided for @fixHighlightedRows.
  ///
  /// In en, this message translates to:
  /// **'Fix the highlighted rows first'**
  String get fixHighlightedRows;

  /// No description provided for @lessonCancelledBanner.
  ///
  /// In en, this message translates to:
  /// **'This lesson was cancelled; its scores are read-only.'**
  String get lessonCancelledBanner;

  /// No description provided for @lessonCancelledReasonBanner.
  ///
  /// In en, this message translates to:
  /// **'This lesson was cancelled ({reason}); its scores are read-only.'**
  String lessonCancelledReasonBanner(String reason);

  /// No description provided for @windowClosedBanner.
  ///
  /// In en, this message translates to:
  /// **'Scores can be changed for 3 days after the lesson, and no later than Saturday 08:00. Ask an admin to correct this lesson.'**
  String get windowClosedBanner;

  /// No description provided for @noStudents.
  ///
  /// In en, this message translates to:
  /// **'No students are enrolled in this class on this date.'**
  String get noStudents;

  /// No description provided for @unsavedTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedTitle;

  /// No description provided for @unsavedBody.
  ///
  /// In en, this message translates to:
  /// **'Leave without saving your changes?'**
  String get unsavedBody;

  /// No description provided for @stay.
  ///
  /// In en, this message translates to:
  /// **'Stay'**
  String get stay;

  /// No description provided for @leave.
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leave;

  /// No description provided for @commentHint.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentHint;

  /// No description provided for @whyBelow40.
  ///
  /// In en, this message translates to:
  /// **'Why below 40? (required)'**
  String get whyBelow40;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional with a reason)'**
  String get noteOptional;

  /// No description provided for @foldAll.
  ///
  /// In en, this message translates to:
  /// **'Fold all'**
  String get foldAll;

  /// No description provided for @unfoldAll.
  ///
  /// In en, this message translates to:
  /// **'Unfold all'**
  String get unfoldAll;

  /// No description provided for @uploads.
  ///
  /// In en, this message translates to:
  /// **'Uploads'**
  String get uploads;

  /// No description provided for @tryNow.
  ///
  /// In en, this message translates to:
  /// **'Try now'**
  String get tryNow;

  /// No description provided for @notAccepted.
  ///
  /// In en, this message translates to:
  /// **'Not accepted: {reason}'**
  String notAccepted(String reason);

  /// No description provided for @waitingForConnection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for a connection ({tries} tries)'**
  String waitingForConnection(int tries);

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @behavior.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get behavior;

  /// No description provided for @waitingToUpload.
  ///
  /// In en, this message translates to:
  /// **'{count} waiting to upload'**
  String waitingToUpload(int count);

  /// No description provided for @notAcceptedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} not accepted'**
  String notAcceptedCount(int count);

  /// No description provided for @signOutUnsent.
  ///
  /// In en, this message translates to:
  /// **'{count} saves are still on this phone and will be lost if you sign out.'**
  String signOutUnsent(int count);

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @classShort.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get classShort;

  /// No description provided for @myClass.
  ///
  /// In en, this message translates to:
  /// **'My Class'**
  String get myClass;

  /// No description provided for @grades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get grades;

  /// No description provided for @exams.
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get exams;

  /// No description provided for @timetable.
  ///
  /// In en, this message translates to:
  /// **'Timetable'**
  String get timetable;

  /// No description provided for @rewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// No description provided for @colleagues.
  ///
  /// In en, this message translates to:
  /// **'Colleagues'**
  String get colleagues;

  /// No description provided for @pointReport.
  ///
  /// In en, this message translates to:
  /// **'Point Report'**
  String get pointReport;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @hiName.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name}'**
  String hiName(String name);

  /// No description provided for @lessonsExamsCount.
  ///
  /// In en, this message translates to:
  /// **'Lessons: {lessons} · Exams: {exams}'**
  String lessonsExamsCount(int lessons, int exams);

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load. Check your connection.'**
  String get loadFailed;

  /// No description provided for @noClassesYet.
  ///
  /// In en, this message translates to:
  /// **'No classes assigned to you yet.'**
  String get noClassesYet;

  /// No description provided for @noGradesYet.
  ///
  /// In en, this message translates to:
  /// **'No grades yet.'**
  String get noGradesYet;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @student.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get student;

  /// No description provided for @averageShort.
  ///
  /// In en, this message translates to:
  /// **'Avg'**
  String get averageShort;

  /// No description provided for @examsShort.
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get examsShort;

  /// No description provided for @reportStudent.
  ///
  /// In en, this message translates to:
  /// **'Report Student'**
  String get reportStudent;

  /// No description provided for @reportShort.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get reportShort;

  /// No description provided for @markTab.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get markTab;

  /// No description provided for @historyTab.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get historyTab;

  /// No description provided for @statisticsTab.
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get statisticsTab;

  /// No description provided for @stepWho.
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get stepWho;

  /// No description provided for @stepWhatKind.
  ///
  /// In en, this message translates to:
  /// **'What kind'**
  String get stepWhatKind;

  /// No description provided for @stepWhy.
  ///
  /// In en, this message translates to:
  /// **'Why'**
  String get stepWhy;

  /// No description provided for @searchAnyStudent.
  ///
  /// In en, this message translates to:
  /// **'Search any student…'**
  String get searchAnyStudent;

  /// No description provided for @otherClass.
  ///
  /// In en, this message translates to:
  /// **'Other class…'**
  String get otherClass;

  /// No description provided for @mine.
  ///
  /// In en, this message translates to:
  /// **'mine'**
  String get mine;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAll;

  /// No description provided for @unselectAll.
  ///
  /// In en, this message translates to:
  /// **'Unselect all'**
  String get unselectAll;

  /// No description provided for @tapStudentsFirst.
  ///
  /// In en, this message translates to:
  /// **'Tap the students first'**
  String get tapStudentsFirst;

  /// No description provided for @nextWho.
  ///
  /// In en, this message translates to:
  /// **'Next · {who}'**
  String nextWho(String who);

  /// No description provided for @pickOneAbove.
  ///
  /// In en, this message translates to:
  /// **'Pick one above'**
  String get pickOneAbove;

  /// No description provided for @pickReasonOrComment.
  ///
  /// In en, this message translates to:
  /// **'Pick a reason or write a comment'**
  String get pickReasonOrComment;

  /// No description provided for @saveForWho.
  ///
  /// In en, this message translates to:
  /// **'Save for {who}'**
  String saveForWho(String who);

  /// No description provided for @savedForWho.
  ///
  /// In en, this message translates to:
  /// **'Saved for {who}'**
  String savedForWho(String who);

  /// No description provided for @seeInHistory.
  ///
  /// In en, this message translates to:
  /// **'See it in history'**
  String get seeInHistory;

  /// No description provided for @markMore.
  ///
  /// In en, this message translates to:
  /// **'Mark more'**
  String get markMore;

  /// No description provided for @markMoreIn.
  ///
  /// In en, this message translates to:
  /// **'Mark more in {cls}'**
  String markMoreIn(String cls);

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @positive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get positive;

  /// No description provided for @needsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get needsAttention;

  /// No description provided for @positiveDetail.
  ///
  /// In en, this message translates to:
  /// **'Something worth praising'**
  String get positiveDetail;

  /// No description provided for @negativeDetail.
  ///
  /// In en, this message translates to:
  /// **'Something to work on'**
  String get negativeDetail;

  /// No description provided for @addCommentOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a comment (optional)'**
  String get addCommentOptional;

  /// No description provided for @noStudentNamed.
  ///
  /// In en, this message translates to:
  /// **'No student with that name.'**
  String get noStudentNamed;

  /// No description provided for @noStudentsInClass.
  ///
  /// In en, this message translates to:
  /// **'No students in this class.'**
  String get noStudentsInClass;

  /// No description provided for @loadingStudents.
  ///
  /// In en, this message translates to:
  /// **'Loading students…'**
  String get loadingStudents;

  /// No description provided for @acrossSchool.
  ///
  /// In en, this message translates to:
  /// **'{count} across the school'**
  String acrossSchool(int count);

  /// No description provided for @studentOrClass.
  ///
  /// In en, this message translates to:
  /// **'Student or class'**
  String get studentOrClass;

  /// No description provided for @noFilterMatches.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches these filters.'**
  String get noFilterMatches;

  /// No description provided for @noBehaviorMarks.
  ///
  /// In en, this message translates to:
  /// **'No behavior marks yet.'**
  String get noBehaviorMarks;

  /// No description provided for @from.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get from;

  /// No description provided for @to.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get to;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @byClass.
  ///
  /// In en, this message translates to:
  /// **'By class'**
  String get byClass;

  /// No description provided for @byWeek.
  ///
  /// In en, this message translates to:
  /// **'By week'**
  String get byWeek;

  /// No description provided for @commonReasons.
  ///
  /// In en, this message translates to:
  /// **'Common reasons'**
  String get commonReasons;

  /// No description provided for @noMarksForPeriod.
  ///
  /// In en, this message translates to:
  /// **'No marks for this period.'**
  String get noMarksForPeriod;

  /// No description provided for @myPlan.
  ///
  /// In en, this message translates to:
  /// **'My Plan'**
  String get myPlan;

  /// No description provided for @myPoints.
  ///
  /// In en, this message translates to:
  /// **'My Points'**
  String get myPoints;

  /// No description provided for @myFundings.
  ///
  /// In en, this message translates to:
  /// **'My Fundings'**
  String get myFundings;

  /// No description provided for @teachingTools.
  ///
  /// In en, this message translates to:
  /// **'Teaching Tools'**
  String get teachingTools;

  /// No description provided for @teachingShort.
  ///
  /// In en, this message translates to:
  /// **'Teaching'**
  String get teachingShort;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get thisMonth;

  /// No description provided for @last30Days.
  ///
  /// In en, this message translates to:
  /// **'Last 30 days'**
  String get last30Days;

  /// No description provided for @thisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYear;

  /// No description provided for @moreFilters.
  ///
  /// In en, this message translates to:
  /// **'More filters'**
  String get moreFilters;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All categories'**
  String get allCategories;

  /// No description provided for @historyCount.
  ///
  /// In en, this message translates to:
  /// **'History ({count})'**
  String historyCount(int count);

  /// No description provided for @inThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'{amount} in this period'**
  String inThisPeriod(String amount);

  /// No description provided for @noPointsYet.
  ///
  /// In en, this message translates to:
  /// **'Points you\'re awarded or that are deducted will show up here.'**
  String get noPointsYet;

  /// No description provided for @nothingInPeriod.
  ///
  /// In en, this message translates to:
  /// **'Nothing in this period.'**
  String get nothingInPeriod;

  /// No description provided for @noSavingsYet.
  ///
  /// In en, this message translates to:
  /// **'Your savings will show up here.'**
  String get noSavingsYet;

  /// No description provided for @showAmounts.
  ///
  /// In en, this message translates to:
  /// **'Show amounts'**
  String get showAmounts;

  /// No description provided for @hideAmounts.
  ///
  /// In en, this message translates to:
  /// **'Hide amounts'**
  String get hideAmounts;

  /// No description provided for @currencySom.
  ///
  /// In en, this message translates to:
  /// **'UZS'**
  String get currencySom;

  /// No description provided for @received.
  ///
  /// In en, this message translates to:
  /// **'Received'**
  String get received;

  /// No description provided for @withdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get withdrawn;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @addMilestone.
  ///
  /// In en, this message translates to:
  /// **'Add milestone'**
  String get addMilestone;

  /// No description provided for @editMilestone.
  ///
  /// In en, this message translates to:
  /// **'Edit milestone'**
  String get editMilestone;

  /// No description provided for @milestones.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestones;

  /// No description provided for @noPlanYet.
  ///
  /// In en, this message translates to:
  /// **'No plan yet. Break the year into the parts you\'ll work through and mark each one off as you go.'**
  String get noPlanYet;

  /// No description provided for @noMilestonesWithStatus.
  ///
  /// In en, this message translates to:
  /// **'Nothing with that status.'**
  String get noMilestonesWithStatus;

  /// No description provided for @planNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Not started'**
  String get planNotStarted;

  /// No description provided for @planInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get planInProgress;

  /// No description provided for @planDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get planDone;

  /// No description provided for @planPostponed.
  ///
  /// In en, this message translates to:
  /// **'Postponed'**
  String get planPostponed;

  /// No description provided for @planCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get planCancelled;

  /// No description provided for @overdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get overdue;

  /// No description provided for @priority.
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get priority;

  /// No description provided for @priorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get priorityLow;

  /// No description provided for @priorityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get priorityMedium;

  /// No description provided for @priorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get priorityHigh;

  /// No description provided for @priorityUrgent.
  ///
  /// In en, this message translates to:
  /// **'Urgent'**
  String get priorityUrgent;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @categoryCurriculum.
  ///
  /// In en, this message translates to:
  /// **'Curriculum'**
  String get categoryCurriculum;

  /// No description provided for @categoryLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get categoryLesson;

  /// No description provided for @categoryExam.
  ///
  /// In en, this message translates to:
  /// **'Exam'**
  String get categoryExam;

  /// No description provided for @categoryMeeting.
  ///
  /// In en, this message translates to:
  /// **'Meeting'**
  String get categoryMeeting;

  /// No description provided for @categoryAdministrative.
  ///
  /// In en, this message translates to:
  /// **'Administrative'**
  String get categoryAdministrative;

  /// No description provided for @categoryPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get categoryPersonal;

  /// No description provided for @categoryGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get categoryGeneral;

  /// No description provided for @starts.
  ///
  /// In en, this message translates to:
  /// **'Starts'**
  String get starts;

  /// No description provided for @ends.
  ///
  /// In en, this message translates to:
  /// **'Ends'**
  String get ends;

  /// No description provided for @milestoneTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Title, e.g. Term 1 algebra unit'**
  String get milestoneTitleHint;

  /// No description provided for @addFiles.
  ///
  /// In en, this message translates to:
  /// **'Add files'**
  String get addFiles;

  /// No description provided for @fileTooBig.
  ///
  /// In en, this message translates to:
  /// **'{name} is larger than 10 MB'**
  String fileTooBig(String name);

  /// No description provided for @milestoneNeedsTitle.
  ///
  /// In en, this message translates to:
  /// **'Give the milestone a title'**
  String get milestoneNeedsTitle;

  /// No description provided for @endBeforeStart.
  ///
  /// In en, this message translates to:
  /// **'The end date can\'t come before the start date'**
  String get endBeforeStart;

  /// No description provided for @milestoneAdded.
  ///
  /// In en, this message translates to:
  /// **'Milestone added'**
  String get milestoneAdded;

  /// No description provided for @milestoneUpdated.
  ///
  /// In en, this message translates to:
  /// **'Milestone updated'**
  String get milestoneUpdated;

  /// No description provided for @milestoneDeleted.
  ///
  /// In en, this message translates to:
  /// **'Milestone deleted'**
  String get milestoneDeleted;

  /// No description provided for @couldNotSaveMilestone.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the milestone'**
  String get couldNotSaveMilestone;

  /// No description provided for @couldNotDeleteMilestone.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the milestone'**
  String get couldNotDeleteMilestone;

  /// No description provided for @planStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the status'**
  String get planStatusFailed;

  /// No description provided for @deleteMilestoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete this milestone?'**
  String get deleteMilestoneTitle;

  /// No description provided for @deleteMilestoneBody.
  ///
  /// In en, this message translates to:
  /// **'\"{agenda}\" and its attachments will be removed. This can\'t be undone.'**
  String deleteMilestoneBody(String agenda);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @soon.
  ///
  /// In en, this message translates to:
  /// **'Soon'**
  String get soon;

  /// No description provided for @teamShuffle.
  ///
  /// In en, this message translates to:
  /// **'Team Shuffle'**
  String get teamShuffle;

  /// No description provided for @namePicker.
  ///
  /// In en, this message translates to:
  /// **'Name Picker'**
  String get namePicker;

  /// No description provided for @timer.
  ///
  /// In en, this message translates to:
  /// **'Timer'**
  String get timer;

  /// No description provided for @participation.
  ///
  /// In en, this message translates to:
  /// **'Participation'**
  String get participation;

  /// No description provided for @homeworkCheck.
  ///
  /// In en, this message translates to:
  /// **'Homework Check'**
  String get homeworkCheck;

  /// No description provided for @balancedTeams.
  ///
  /// In en, this message translates to:
  /// **'Balanced Teams'**
  String get balancedTeams;

  /// No description provided for @seatingPlan.
  ///
  /// In en, this message translates to:
  /// **'Seating Plan'**
  String get seatingPlan;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @absentQuestion.
  ///
  /// In en, this message translates to:
  /// **'Absent?'**
  String get absentQuestion;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get startOver;

  /// No description provided for @fewerTeams.
  ///
  /// In en, this message translates to:
  /// **'Fewer teams'**
  String get fewerTeams;

  /// No description provided for @moreTeams.
  ///
  /// In en, this message translates to:
  /// **'More teams'**
  String get moreTeams;

  /// No description provided for @roles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// No description provided for @shuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get shuffle;

  /// No description provided for @again.
  ///
  /// In en, this message translates to:
  /// **'Again'**
  String get again;

  /// No description provided for @teamRed.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get teamRed;

  /// No description provided for @teamBlue.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get teamBlue;

  /// No description provided for @teamGreen.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get teamGreen;

  /// No description provided for @teamYellow.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get teamYellow;

  /// No description provided for @teamPurple.
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get teamPurple;

  /// No description provided for @teamOrange.
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get teamOrange;

  /// No description provided for @teamPink.
  ///
  /// In en, this message translates to:
  /// **'Pink'**
  String get teamPink;

  /// No description provided for @teamTeal.
  ///
  /// In en, this message translates to:
  /// **'Teal'**
  String get teamTeal;

  /// No description provided for @roleLeader.
  ///
  /// In en, this message translates to:
  /// **'Leader'**
  String get roleLeader;

  /// No description provided for @roleTimekeeper.
  ///
  /// In en, this message translates to:
  /// **'Timekeeper'**
  String get roleTimekeeper;

  /// No description provided for @roleRecorder.
  ///
  /// In en, this message translates to:
  /// **'Recorder'**
  String get roleRecorder;

  /// No description provided for @roleReporter.
  ///
  /// In en, this message translates to:
  /// **'Reporter'**
  String get roleReporter;

  /// No description provided for @roleChecker.
  ///
  /// In en, this message translates to:
  /// **'Checker'**
  String get roleChecker;

  /// No description provided for @roleEncourager.
  ///
  /// In en, this message translates to:
  /// **'Encourager'**
  String get roleEncourager;

  /// No description provided for @roleMaterials.
  ///
  /// In en, this message translates to:
  /// **'Materials'**
  String get roleMaterials;

  /// No description provided for @roleQuestioner.
  ///
  /// In en, this message translates to:
  /// **'Questioner'**
  String get roleQuestioner;

  /// No description provided for @roleHelper.
  ///
  /// In en, this message translates to:
  /// **'Helper'**
  String get roleHelper;

  /// No description provided for @oneMinuteLess.
  ///
  /// In en, this message translates to:
  /// **'One minute less'**
  String get oneMinuteLess;

  /// No description provided for @oneMinuteMore.
  ///
  /// In en, this message translates to:
  /// **'One minute more'**
  String get oneMinuteMore;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @start.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// No description provided for @reset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @comingSoonBody.
  ///
  /// In en, this message translates to:
  /// **'This part of the app isn\'t ready yet.'**
  String get comingSoonBody;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Pages, students, codes…'**
  String get searchHint;

  /// No description provided for @searchPagesHint.
  ///
  /// In en, this message translates to:
  /// **'Search the app…'**
  String get searchPagesHint;

  /// No description provided for @searchSuggested.
  ///
  /// In en, this message translates to:
  /// **'Suggested'**
  String get searchSuggested;

  /// No description provided for @searchPages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get searchPages;

  /// No description provided for @searchPeople.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get searchPeople;

  /// No description provided for @searchFound.
  ///
  /// In en, this message translates to:
  /// **'{count} found'**
  String searchFound(int count);

  /// No description provided for @searchMinChars.
  ///
  /// In en, this message translates to:
  /// **'Type {count} letters to search people'**
  String searchMinChars(int count);

  /// No description provided for @searchNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing found for “{query}”'**
  String searchNothing(String query);

  /// No description provided for @searchNothingBody.
  ///
  /// In en, this message translates to:
  /// **'Try another spelling, a student code or a page name.'**
  String get searchNothingBody;

  /// No description provided for @searchNothingPagesBody.
  ///
  /// In en, this message translates to:
  /// **'Try another word for the page.'**
  String get searchNothingPagesBody;

  /// No description provided for @searchShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get searchShowMore;

  /// No description provided for @searchLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get searchLeft;

  /// No description provided for @searchGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade {grade}'**
  String searchGrade(int grade);

  /// No description provided for @searchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t search people.'**
  String get searchFailed;

  /// No description provided for @colleaguesActive.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 active colleague} other{{count} active colleagues}}'**
  String colleaguesActive(int count);

  /// No description provided for @colleaguesNone.
  ///
  /// In en, this message translates to:
  /// **'No colleagues found.'**
  String get colleaguesNone;

  /// No description provided for @colleaguesNoneMatching.
  ///
  /// In en, this message translates to:
  /// **'No colleagues match your search.'**
  String get colleaguesNoneMatching;

  /// No description provided for @colleaguesNoPhone.
  ///
  /// In en, this message translates to:
  /// **'No phone number'**
  String get colleaguesNoPhone;

  /// No description provided for @colleaguesCall.
  ///
  /// In en, this message translates to:
  /// **'Call {name}'**
  String colleaguesCall(String name);

  /// No description provided for @colleaguesMessage.
  ///
  /// In en, this message translates to:
  /// **'Message {name}'**
  String colleaguesMessage(String name);

  /// No description provided for @colleaguesCopied.
  ///
  /// In en, this message translates to:
  /// **'Number copied'**
  String get colleaguesCopied;

  /// No description provided for @colleaguesCantCall.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the phone app.'**
  String get colleaguesCantCall;

  /// No description provided for @colleaguesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load colleagues.'**
  String get colleaguesLoadFailed;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset filters'**
  String get resetFilters;

  /// No description provided for @pointsFor.
  ///
  /// In en, this message translates to:
  /// **'For {date}'**
  String pointsFor(String date);

  /// No description provided for @pointsEdited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get pointsEdited;

  /// No description provided for @pointsRefreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh your points.'**
  String get pointsRefreshFailed;

  /// No description provided for @pointsWiderPeriod.
  ///
  /// In en, this message translates to:
  /// **'Try a wider period.'**
  String get pointsWiderPeriod;

  /// No description provided for @colleaguesSwipeCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get colleaguesSwipeCall;

  /// No description provided for @colleaguesSwipeMessage.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get colleaguesSwipeMessage;

  /// No description provided for @classStudentsTab.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get classStudentsTab;

  /// No description provided for @classGradesTab.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get classGradesTab;

  /// No description provided for @classBehaviorTab.
  ///
  /// In en, this message translates to:
  /// **'Behavior'**
  String get classBehaviorTab;

  /// No description provided for @classStudentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 student} other{{count} students}}'**
  String classStudentCount(int count);

  /// No description provided for @classLeft.
  ///
  /// In en, this message translates to:
  /// **'Left'**
  String get classLeft;

  /// No description provided for @classPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get classPresent;

  /// No description provided for @classContacts.
  ///
  /// In en, this message translates to:
  /// **'Contacts'**
  String get classContacts;

  /// No description provided for @classNoContacts.
  ///
  /// In en, this message translates to:
  /// **'No contacts yet.'**
  String get classNoContacts;

  /// No description provided for @classEditContacts.
  ///
  /// In en, this message translates to:
  /// **'Edit contacts'**
  String get classEditContacts;

  /// No description provided for @classNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students in this class.'**
  String get classNoStudents;

  /// No description provided for @classNoHomeroom.
  ///
  /// In en, this message translates to:
  /// **'No class assigned'**
  String get classNoHomeroom;

  /// No description provided for @classNoHomeroomBody.
  ///
  /// In en, this message translates to:
  /// **'You aren\'t the homeroom teacher of a class this year.'**
  String get classNoHomeroomBody;

  /// No description provided for @classGradesNone.
  ///
  /// In en, this message translates to:
  /// **'No grades yet'**
  String get classGradesNone;

  /// No description provided for @classGradesFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load grades.'**
  String get classGradesFailed;

  /// No description provided for @classDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get classDaily;

  /// No description provided for @classGraded.
  ///
  /// In en, this message translates to:
  /// **'Graded'**
  String get classGraded;

  /// No description provided for @classCatAttend.
  ///
  /// In en, this message translates to:
  /// **'Attend'**
  String get classCatAttend;

  /// No description provided for @classCatBooks.
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get classCatBooks;

  /// No description provided for @classCatHomework.
  ///
  /// In en, this message translates to:
  /// **'HW'**
  String get classCatHomework;

  /// No description provided for @classCatActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get classCatActive;

  /// No description provided for @classCatNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get classCatNotes;

  /// No description provided for @classBehaviorFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load behavior.'**
  String get classBehaviorFailed;

  /// No description provided for @classPositive.
  ///
  /// In en, this message translates to:
  /// **'Positive'**
  String get classPositive;

  /// No description provided for @classNeedsAttention.
  ///
  /// In en, this message translates to:
  /// **'Needs attention'**
  String get classNeedsAttention;

  /// No description provided for @classMark.
  ///
  /// In en, this message translates to:
  /// **'Mark'**
  String get classMark;

  /// No description provided for @classNoMarks.
  ///
  /// In en, this message translates to:
  /// **'No marks yet'**
  String get classNoMarks;

  /// No description provided for @classAllMarks.
  ///
  /// In en, this message translates to:
  /// **'All {count}'**
  String classAllMarks(int count);

  /// No description provided for @notMarkedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} not marked'**
  String notMarkedCount(int count);

  /// No description provided for @allMarked.
  ///
  /// In en, this message translates to:
  /// **'All marked'**
  String get allMarked;

  /// No description provided for @notMarked.
  ///
  /// In en, this message translates to:
  /// **'not marked'**
  String get notMarked;

  /// No description provided for @notFinished.
  ///
  /// In en, this message translates to:
  /// **'{count} not finished'**
  String notFinished(int count);

  /// No description provided for @scoreEveryCategory.
  ///
  /// In en, this message translates to:
  /// **'Score every category for {count} student(s) first'**
  String scoreEveryCategory(int count);

  /// No description provided for @oldGradingLesson.
  ///
  /// In en, this message translates to:
  /// **'this lesson was marked before the new grading, so it uses the old categories'**
  String get oldGradingLesson;

  /// No description provided for @profileAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get profileAccount;

  /// No description provided for @profileApp.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get profileApp;

  /// No description provided for @profileEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get profileEmail;

  /// No description provided for @profilePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get profilePhone;

  /// No description provided for @profilePassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get profilePassword;

  /// No description provided for @profileSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get profileSystem;

  /// No description provided for @profileSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Language, color, dark mode'**
  String get profileSystemHint;

  /// No description provided for @profileSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get profileSuggestions;

  /// No description provided for @profileLogOut.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogOut;

  /// No description provided for @profileNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get profileNotSet;

  /// No description provided for @profileContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact details'**
  String get profileContactTitle;

  /// No description provided for @profileInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address'**
  String get profileInvalidEmail;

  /// No description provided for @profileInvalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number'**
  String get profileInvalidPhone;

  /// No description provided for @profileContactSaved.
  ///
  /// In en, this message translates to:
  /// **'Contact details updated'**
  String get profileContactSaved;

  /// No description provided for @profileContactFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update contact details'**
  String get profileContactFailed;

  /// No description provided for @suggestionsLead.
  ///
  /// In en, this message translates to:
  /// **'Ideas, problems, questions — we read every one.'**
  String get suggestionsLead;

  /// No description provided for @suggestionsPrompt.
  ///
  /// In en, this message translates to:
  /// **'What should we improve?'**
  String get suggestionsPrompt;

  /// No description provided for @suggestionsHint.
  ///
  /// In en, this message translates to:
  /// **'Type your suggestion…'**
  String get suggestionsHint;

  /// No description provided for @suggestionsAnonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get suggestionsAnonymous;

  /// No description provided for @suggestionsSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get suggestionsSend;

  /// No description provided for @suggestionsSentButton.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get suggestionsSentButton;

  /// No description provided for @suggestionsSent.
  ///
  /// In en, this message translates to:
  /// **'Sent — thank you!'**
  String get suggestionsSent;

  /// No description provided for @suggestionsFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Try again.'**
  String get suggestionsFailed;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @calendar.
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendar;

  /// No description provided for @calToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calToday;

  /// No description provided for @calMonthView.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calMonthView;

  /// No description provided for @calScheduleView.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get calScheduleView;

  /// No description provided for @calNewEvent.
  ///
  /// In en, this message translates to:
  /// **'New event'**
  String get calNewEvent;

  /// No description provided for @calEditEvent.
  ///
  /// In en, this message translates to:
  /// **'Edit event'**
  String get calEditEvent;

  /// No description provided for @calEvents.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get calEvents;

  /// No description provided for @calHolidays.
  ///
  /// In en, this message translates to:
  /// **'Holidays'**
  String get calHolidays;

  /// No description provided for @calTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms'**
  String get calTerms;

  /// No description provided for @calExams.
  ///
  /// In en, this message translates to:
  /// **'Exams'**
  String get calExams;

  /// No description provided for @calAllEvents.
  ///
  /// In en, this message translates to:
  /// **'All events'**
  String get calAllEvents;

  /// No description provided for @calNothingOnDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing on this day'**
  String get calNothingOnDay;

  /// No description provided for @calEvent.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get calEvent;

  /// No description provided for @calHoliday.
  ///
  /// In en, this message translates to:
  /// **'Holiday'**
  String get calHoliday;

  /// No description provided for @calTermStarts.
  ///
  /// In en, this message translates to:
  /// **'Term starts'**
  String get calTermStarts;

  /// No description provided for @calTermEnds.
  ///
  /// In en, this message translates to:
  /// **'Term ends'**
  String get calTermEnds;

  /// No description provided for @calExamPeriod.
  ///
  /// In en, this message translates to:
  /// **'Exam period'**
  String get calExamPeriod;

  /// No description provided for @calAllDay.
  ///
  /// In en, this message translates to:
  /// **'All day'**
  String get calAllDay;

  /// No description provided for @calCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get calCancelled;

  /// No description provided for @calDraft.
  ///
  /// In en, this message translates to:
  /// **'Draft'**
  String get calDraft;

  /// No description provided for @calCancelEvent.
  ///
  /// In en, this message translates to:
  /// **'Cancel event'**
  String get calCancelEvent;

  /// No description provided for @calCancelEventQ.
  ///
  /// In en, this message translates to:
  /// **'Cancel this event?'**
  String get calCancelEventQ;

  /// No description provided for @calDeleteEventQ.
  ///
  /// In en, this message translates to:
  /// **'Delete this event?'**
  String get calDeleteEventQ;

  /// No description provided for @calEventCancelled.
  ///
  /// In en, this message translates to:
  /// **'Event cancelled'**
  String get calEventCancelled;

  /// No description provided for @calEventDeleted.
  ///
  /// In en, this message translates to:
  /// **'Event deleted'**
  String get calEventDeleted;

  /// No description provided for @calChangeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the change'**
  String get calChangeFailed;

  /// No description provided for @calTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get calTitle;

  /// No description provided for @calTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get calTitleRequired;

  /// No description provided for @calCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get calCategory;

  /// No description provided for @calLocation.
  ///
  /// In en, this message translates to:
  /// **'Location'**
  String get calLocation;

  /// No description provided for @calDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get calDescription;

  /// No description provided for @calAudience.
  ///
  /// In en, this message translates to:
  /// **'Who sees it'**
  String get calAudience;

  /// No description provided for @calAddAudience.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get calAddAudience;

  /// No description provided for @calAllStaff.
  ///
  /// In en, this message translates to:
  /// **'All staff'**
  String get calAllStaff;

  /// No description provided for @calAllStudents.
  ///
  /// In en, this message translates to:
  /// **'All students'**
  String get calAllStudents;

  /// No description provided for @calGrade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get calGrade;

  /// No description provided for @calClass.
  ///
  /// In en, this message translates to:
  /// **'Class'**
  String get calClass;

  /// No description provided for @calRole.
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get calRole;

  /// No description provided for @calDepartment.
  ///
  /// In en, this message translates to:
  /// **'Dept'**
  String get calDepartment;

  /// No description provided for @calSaveAsDraft.
  ///
  /// In en, this message translates to:
  /// **'Save as draft'**
  String get calSaveAsDraft;

  /// No description provided for @calNotify.
  ///
  /// In en, this message translates to:
  /// **'Send a notification'**
  String get calNotify;

  /// No description provided for @calCatGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get calCatGeneral;

  /// No description provided for @calCatCeremony.
  ///
  /// In en, this message translates to:
  /// **'Ceremony'**
  String get calCatCeremony;

  /// No description provided for @calCatParentMeeting.
  ///
  /// In en, this message translates to:
  /// **'Parent meeting'**
  String get calCatParentMeeting;

  /// No description provided for @calCatTrip.
  ///
  /// In en, this message translates to:
  /// **'Trip'**
  String get calCatTrip;

  /// No description provided for @calCatSports.
  ///
  /// In en, this message translates to:
  /// **'Sports'**
  String get calCatSports;

  /// No description provided for @calCatCompetition.
  ///
  /// In en, this message translates to:
  /// **'Competition'**
  String get calCatCompetition;

  /// No description provided for @calCatDeadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get calCatDeadline;

  /// No description provided for @calCatStaff.
  ///
  /// In en, this message translates to:
  /// **'Staff'**
  String get calCatStaff;

  /// No description provided for @calCatOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get calCatOther;

  /// No description provided for @myLessonAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Lesson analysis results'**
  String get myLessonAnalysis;

  /// No description provided for @myAnalysisShort.
  ///
  /// In en, this message translates to:
  /// **'My Analysis'**
  String get myAnalysisShort;

  /// No description provided for @lessonAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Lesson Analysis'**
  String get lessonAnalysis;

  /// No description provided for @laNoneYet.
  ///
  /// In en, this message translates to:
  /// **'No analyses yet. When one of your lessons is analysed, the results and feedback show up here.'**
  String get laNoneYet;

  /// No description provided for @laTotalPoints.
  ///
  /// In en, this message translates to:
  /// **'Total points'**
  String get laTotalPoints;

  /// No description provided for @laThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get laThisMonth;

  /// No description provided for @laLastMonth.
  ///
  /// In en, this message translates to:
  /// **'Last month'**
  String get laLastMonth;

  /// No description provided for @laAllTime.
  ///
  /// In en, this message translates to:
  /// **'All time'**
  String get laAllTime;

  /// No description provided for @laAnalyses.
  ///
  /// In en, this message translates to:
  /// **'Analyses'**
  String get laAnalyses;

  /// No description provided for @laLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get laLatest;

  /// No description provided for @laNotesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} notes'**
  String laNotesCount(int count);

  /// No description provided for @laNoNotes.
  ///
  /// In en, this message translates to:
  /// **'No notes'**
  String get laNoNotes;

  /// No description provided for @laMyDepartment.
  ///
  /// In en, this message translates to:
  /// **'My department'**
  String get laMyDepartment;

  /// No description provided for @laAnalysedOf.
  ///
  /// In en, this message translates to:
  /// **'{analysed} of {total} teachers analysed'**
  String laAnalysedOf(int analysed, int total);

  /// No description provided for @laAnalysesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} analyses'**
  String laAnalysesCount(int count);

  /// No description provided for @laNotAnalysed.
  ///
  /// In en, this message translates to:
  /// **'Not analysed yet'**
  String get laNotAnalysed;

  /// No description provided for @laSortLast.
  ///
  /// In en, this message translates to:
  /// **'Last analysed'**
  String get laSortLast;

  /// No description provided for @laSortMost.
  ///
  /// In en, this message translates to:
  /// **'Most points'**
  String get laSortMost;

  /// No description provided for @laSortLeast.
  ///
  /// In en, this message translates to:
  /// **'Fewest points'**
  String get laSortLeast;

  /// No description provided for @laSortName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get laSortName;

  /// No description provided for @laNewAnalysis.
  ///
  /// In en, this message translates to:
  /// **'New analysis'**
  String get laNewAnalysis;

  /// No description provided for @laEditAnalysis.
  ///
  /// In en, this message translates to:
  /// **'Edit analysis'**
  String get laEditAnalysis;

  /// No description provided for @laDeleteQ.
  ///
  /// In en, this message translates to:
  /// **'Delete this analysis?'**
  String get laDeleteQ;

  /// No description provided for @laDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Its points are taken back from the teacher.'**
  String get laDeleteBody;

  /// No description provided for @laDeleted.
  ///
  /// In en, this message translates to:
  /// **'Analysis deleted'**
  String get laDeleted;

  /// No description provided for @laTeacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get laTeacher;

  /// No description provided for @laLesson.
  ///
  /// In en, this message translates to:
  /// **'Lesson'**
  String get laLesson;

  /// No description provided for @laNoLessons.
  ///
  /// In en, this message translates to:
  /// **'No lessons in the last 60 days that can be analysed.'**
  String get laNoLessons;

  /// No description provided for @laAnalysed.
  ///
  /// In en, this message translates to:
  /// **'analysed'**
  String get laAnalysed;

  /// No description provided for @laPoints.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get laPoints;

  /// No description provided for @laNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get laNotes;

  /// No description provided for @laChooseTeacher.
  ///
  /// In en, this message translates to:
  /// **'Choose the teacher'**
  String get laChooseTeacher;

  /// No description provided for @laChooseLesson.
  ///
  /// In en, this message translates to:
  /// **'Choose the lesson'**
  String get laChooseLesson;

  /// No description provided for @laPointsWhole.
  ///
  /// In en, this message translates to:
  /// **'Points must be a whole number'**
  String get laPointsWhole;

  /// No description provided for @laSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get laSaved;

  /// No description provided for @laSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the analysis'**
  String get laSaveFailed;

  /// No description provided for @myDepartment.
  ///
  /// In en, this message translates to:
  /// **'My Department'**
  String get myDepartment;

  /// No description provided for @deptNone.
  ///
  /// In en, this message translates to:
  /// **'You don\'t lead a department.'**
  String get deptNone;

  /// No description provided for @deptHead.
  ///
  /// In en, this message translates to:
  /// **'Head'**
  String get deptHead;

  /// No description provided for @deptDeputy.
  ///
  /// In en, this message translates to:
  /// **'Deputy'**
  String get deptDeputy;

  /// No description provided for @deptCounts.
  ///
  /// In en, this message translates to:
  /// **'{subjects} subjects · {members} members'**
  String deptCounts(int subjects, int members);

  /// No description provided for @deptLessons.
  ///
  /// In en, this message translates to:
  /// **'Lessons'**
  String get deptLessons;

  /// No description provided for @deptAttendanceTaken.
  ///
  /// In en, this message translates to:
  /// **'Attendance taken'**
  String get deptAttendanceTaken;

  /// No description provided for @deptGradesEntered.
  ///
  /// In en, this message translates to:
  /// **'Grades entered'**
  String get deptGradesEntered;

  /// No description provided for @deptGrades.
  ///
  /// In en, this message translates to:
  /// **'Grades'**
  String get deptGrades;

  /// No description provided for @deptAvgGrade.
  ///
  /// In en, this message translates to:
  /// **'Avg grade'**
  String get deptAvgGrade;

  /// No description provided for @deptAttendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get deptAttendance;

  /// No description provided for @deptExamAvg.
  ///
  /// In en, this message translates to:
  /// **'Exam avg'**
  String get deptExamAvg;

  /// No description provided for @deptKpi.
  ///
  /// In en, this message translates to:
  /// **'KPI'**
  String get deptKpi;

  /// No description provided for @deptTeachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get deptTeachers;

  /// No description provided for @deptSubjects.
  ///
  /// In en, this message translates to:
  /// **'Subjects'**
  String get deptSubjects;

  /// No description provided for @deptClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get deptClasses;

  /// No description provided for @deptAllClasses.
  ///
  /// In en, this message translates to:
  /// **'All classes'**
  String get deptAllClasses;

  /// No description provided for @cashier.
  ///
  /// In en, this message translates to:
  /// **'Cashier'**
  String get cashier;

  /// No description provided for @cashReview.
  ///
  /// In en, this message translates to:
  /// **'Behaviour marks with no reason'**
  String get cashReview;

  /// No description provided for @cashSync.
  ///
  /// In en, this message translates to:
  /// **'Sync grades'**
  String get cashSync;

  /// No description provided for @cashSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Sync failed'**
  String get cashSyncFailed;

  /// No description provided for @cashSyncedThrough.
  ///
  /// In en, this message translates to:
  /// **'Synced through {date}'**
  String cashSyncedThrough(String date);

  /// No description provided for @cashClasses.
  ///
  /// In en, this message translates to:
  /// **'Classes'**
  String get cashClasses;

  /// No description provided for @cashRanking.
  ///
  /// In en, this message translates to:
  /// **'School ranking'**
  String get cashRanking;

  /// No description provided for @cashSearch.
  ///
  /// In en, this message translates to:
  /// **'Student name'**
  String get cashSearch;

  /// No description provided for @cashAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get cashAmount;

  /// No description provided for @cashNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get cashNote;

  /// No description provided for @cashSpend.
  ///
  /// In en, this message translates to:
  /// **'Spend'**
  String get cashSpend;

  /// No description provided for @cashAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get cashAdd;

  /// No description provided for @cashResetQ.
  ///
  /// In en, this message translates to:
  /// **'Set this balance to \$0?'**
  String get cashResetQ;

  /// No description provided for @cashResetZero.
  ///
  /// In en, this message translates to:
  /// **'Reset to \$0'**
  String get cashResetZero;

  /// No description provided for @cashHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get cashHistory;

  /// No description provided for @cashNoHistory.
  ///
  /// In en, this message translates to:
  /// **'No history yet'**
  String get cashNoHistory;

  /// No description provided for @attendanceCheck.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendanceCheck;

  /// No description provided for @attNotMarked.
  ///
  /// In en, this message translates to:
  /// **'Not marked'**
  String get attNotMarked;

  /// No description provided for @attOnNow.
  ///
  /// In en, this message translates to:
  /// **'On now'**
  String get attOnNow;

  /// No description provided for @attMarked.
  ///
  /// In en, this message translates to:
  /// **'Marked'**
  String get attMarked;

  /// No description provided for @attLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get attLater;

  /// No description provided for @attNoStudents.
  ///
  /// In en, this message translates to:
  /// **'No students'**
  String get attNoStudents;

  /// No description provided for @attOnlyMissing.
  ///
  /// In en, this message translates to:
  /// **'Only classes with unmarked lessons'**
  String get attOnlyMissing;

  /// No description provided for @attNoLessons.
  ///
  /// In en, this message translates to:
  /// **'No lessons on this day'**
  String get attNoLessons;

  /// No description provided for @attAbsent.
  ///
  /// In en, this message translates to:
  /// **'Absent'**
  String get attAbsent;

  /// No description provided for @attLate.
  ///
  /// In en, this message translates to:
  /// **'Late'**
  String get attLate;

  /// No description provided for @attStatistics.
  ///
  /// In en, this message translates to:
  /// **'Attendance statistics'**
  String get attStatistics;

  /// No description provided for @attThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get attThisWeek;

  /// No description provided for @attThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get attThisMonth;

  /// No description provided for @attAttendanceRate.
  ///
  /// In en, this message translates to:
  /// **'Attendance rate'**
  String get attAttendanceRate;

  /// No description provided for @attPresent.
  ///
  /// In en, this message translates to:
  /// **'Present'**
  String get attPresent;

  /// No description provided for @attExcused.
  ///
  /// In en, this message translates to:
  /// **'Excused'**
  String get attExcused;

  /// No description provided for @attByClass.
  ///
  /// In en, this message translates to:
  /// **'By class'**
  String get attByClass;

  /// No description provided for @attByStudent.
  ///
  /// In en, this message translates to:
  /// **'By student'**
  String get attByStudent;

  /// No description provided for @attNoMarks.
  ///
  /// In en, this message translates to:
  /// **'No attendance marks in this period'**
  String get attNoMarks;

  /// No description provided for @substitutions.
  ///
  /// In en, this message translates to:
  /// **'Substitution'**
  String get substitutions;

  /// No description provided for @subNewAbsence.
  ///
  /// In en, this message translates to:
  /// **'New absence'**
  String get subNewAbsence;

  /// No description provided for @subNone.
  ///
  /// In en, this message translates to:
  /// **'No substitutions in these two weeks'**
  String get subNone;

  /// No description provided for @subNoLessonsYet.
  ///
  /// In en, this message translates to:
  /// **'No lessons arranged yet — tap the absence to cover its lessons.'**
  String get subNoLessonsYet;

  /// No description provided for @subLessonsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} lessons'**
  String subLessonsCount(int count);

  /// No description provided for @subRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get subRemove;

  /// No description provided for @subRemoveQ.
  ///
  /// In en, this message translates to:
  /// **'Remove substitution?'**
  String get subRemoveQ;

  /// No description provided for @subRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'{lesson} at {time} goes back to its original teacher. Nobody is notified.'**
  String subRemoveBody(String lesson, String time);

  /// No description provided for @subRemoved.
  ///
  /// In en, this message translates to:
  /// **'Substitution removed'**
  String get subRemoved;

  /// No description provided for @subCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get subCover;

  /// No description provided for @subMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get subMerge;

  /// No description provided for @subCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get subCancel;

  /// No description provided for @subNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get subNext;

  /// No description provided for @subReasonSick.
  ///
  /// In en, this message translates to:
  /// **'Sick'**
  String get subReasonSick;

  /// No description provided for @subReasonPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get subReasonPersonal;

  /// No description provided for @subReasonTrip.
  ///
  /// In en, this message translates to:
  /// **'Business trip'**
  String get subReasonTrip;

  /// No description provided for @subReasonTraining.
  ///
  /// In en, this message translates to:
  /// **'Training'**
  String get subReasonTraining;

  /// No description provided for @subCoverFor.
  ///
  /// In en, this message translates to:
  /// **'Cover for {name}'**
  String subCoverFor(String name);

  /// No description provided for @subNoAffected.
  ///
  /// In en, this message translates to:
  /// **'This absence has no lessons.'**
  String get subNoAffected;

  /// No description provided for @subArranged.
  ///
  /// In en, this message translates to:
  /// **'Already arranged'**
  String get subArranged;

  /// No description provided for @subPickEach.
  ///
  /// In en, this message translates to:
  /// **'Pick a substitute or a lesson for each one'**
  String get subPickEach;

  /// No description provided for @subSaved.
  ///
  /// In en, this message translates to:
  /// **'Covers saved'**
  String get subSaved;

  /// No description provided for @subBusy.
  ///
  /// In en, this message translates to:
  /// **'busy'**
  String get subBusy;

  /// No description provided for @subAbsent.
  ///
  /// In en, this message translates to:
  /// **'absent'**
  String get subAbsent;

  /// No description provided for @subUnavailable.
  ///
  /// In en, this message translates to:
  /// **'unavailable'**
  String get subUnavailable;

  /// No description provided for @subSubject.
  ///
  /// In en, this message translates to:
  /// **'subject'**
  String get subSubject;

  /// No description provided for @subKnowsClass.
  ///
  /// In en, this message translates to:
  /// **'knows class'**
  String get subKnowsClass;

  /// No description provided for @subCoversMonth.
  ///
  /// In en, this message translates to:
  /// **'{count} covers/mo'**
  String subCoversMonth(int count);

  /// No description provided for @subSubstitute.
  ///
  /// In en, this message translates to:
  /// **'Substitute'**
  String get subSubstitute;

  /// No description provided for @subMergeWith.
  ///
  /// In en, this message translates to:
  /// **'Merge with'**
  String get subMergeWith;

  /// No description provided for @subAssignAnyway.
  ///
  /// In en, this message translates to:
  /// **'Assign anyway'**
  String get subAssignAnyway;

  /// No description provided for @staffPoints.
  ///
  /// In en, this message translates to:
  /// **'Staff Points'**
  String get staffPoints;

  /// No description provided for @spAward.
  ///
  /// In en, this message translates to:
  /// **'Award points'**
  String get spAward;

  /// No description provided for @spAwardShort.
  ///
  /// In en, this message translates to:
  /// **'Award'**
  String get spAwardShort;

  /// No description provided for @spDeduct.
  ///
  /// In en, this message translates to:
  /// **'Deduct'**
  String get spDeduct;

  /// No description provided for @spThisWeek.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get spThisWeek;

  /// No description provided for @spThisYear.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get spThisYear;

  /// No description provided for @spChooseRecipients.
  ///
  /// In en, this message translates to:
  /// **'Choose who'**
  String get spChooseRecipients;

  /// No description provided for @spAllTeachers.
  ///
  /// In en, this message translates to:
  /// **'All teachers'**
  String get spAllTeachers;

  /// No description provided for @spNoCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get spNoCategory;

  /// No description provided for @spNoteRequired.
  ///
  /// In en, this message translates to:
  /// **'Write a note'**
  String get spNoteRequired;

  /// No description provided for @spSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved for {count}'**
  String spSaved(int count);

  /// No description provided for @spSomeFailed.
  ///
  /// In en, this message translates to:
  /// **'{count} couldn\'t be saved'**
  String spSomeFailed(int count);

  /// No description provided for @fundings.
  ///
  /// In en, this message translates to:
  /// **'Fundings'**
  String get fundings;

  /// No description provided for @fundNew.
  ///
  /// In en, this message translates to:
  /// **'New funding'**
  String get fundNew;

  /// No description provided for @fundNone.
  ///
  /// In en, this message translates to:
  /// **'No savings yet'**
  String get fundNone;

  /// No description provided for @fundDeposits.
  ///
  /// In en, this message translates to:
  /// **'Deposits'**
  String get fundDeposits;

  /// No description provided for @fundWithdrawals.
  ///
  /// In en, this message translates to:
  /// **'Withdrawals'**
  String get fundWithdrawals;

  /// No description provided for @fundBalance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get fundBalance;

  /// No description provided for @fundDeposit.
  ///
  /// In en, this message translates to:
  /// **'Deposit'**
  String get fundDeposit;

  /// No description provided for @fundWithdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get fundWithdrawal;

  /// No description provided for @fundPerson.
  ///
  /// In en, this message translates to:
  /// **'Person'**
  String get fundPerson;

  /// No description provided for @fundAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above zero'**
  String get fundAmountPositive;

  /// No description provided for @lunchDuty.
  ///
  /// In en, this message translates to:
  /// **'Lunch duty'**
  String get lunchDuty;

  /// No description provided for @tagLab.
  ///
  /// In en, this message translates to:
  /// **'Lab lesson'**
  String get tagLab;

  /// No description provided for @tagAfter.
  ///
  /// In en, this message translates to:
  /// **'After-school lesson'**
  String get tagAfter;

  /// No description provided for @updTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updTitle;

  /// No description provided for @updNothingNew.
  ///
  /// In en, this message translates to:
  /// **'Nothing new this week'**
  String get updNothingNew;

  /// No description provided for @updJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get updJustNow;

  /// No description provided for @updMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String updMinutesAgo(int count);

  /// No description provided for @updHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String updHoursAgo(int count);

  /// No description provided for @updYesterday.
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get updYesterday;

  /// No description provided for @updDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String updDaysAgo(int count);

  /// No description provided for @updPoints.
  ///
  /// In en, this message translates to:
  /// **'{points} points'**
  String updPoints(String points);

  /// No description provided for @updTakenFrom.
  ///
  /// In en, this message translates to:
  /// **'Taken from {name}'**
  String updTakenFrom(String name);

  /// No description provided for @updAddedTo.
  ///
  /// In en, this message translates to:
  /// **'Added to {name}'**
  String updAddedTo(String name);

  /// No description provided for @updUpcomingEvent.
  ///
  /// In en, this message translates to:
  /// **'Coming up'**
  String get updUpcomingEvent;

  /// No description provided for @updTomorrow.
  ///
  /// In en, this message translates to:
  /// **'tomorrow'**
  String get updTomorrow;

  /// No description provided for @dombitTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dombit \$ PDF for last week'**
  String get dombitTooltip;

  /// No description provided for @dombitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not make the PDF'**
  String get dombitFailed;

  /// No description provided for @updates.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get updates;

  /// No description provided for @whatsNewPhotoZoomTitle.
  ///
  /// In en, this message translates to:
  /// **'Tap a photo to enlarge it'**
  String get whatsNewPhotoZoomTitle;

  /// No description provided for @whatsNewAttendanceTitle.
  ///
  /// In en, this message translates to:
  /// **'Attendance statistics'**
  String get whatsNewAttendanceTitle;

  /// No description provided for @whatsNewAttendanceBody.
  ///
  /// In en, this message translates to:
  /// **'Attendance rates by class and student'**
  String get whatsNewAttendanceBody;

  /// No description provided for @whatsNewPasskeysTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a passkey'**
  String get whatsNewPasskeysTitle;

  /// No description provided for @whatsNewPasskeysBody.
  ///
  /// In en, this message translates to:
  /// **'Use your fingerprint or face instead of a password'**
  String get whatsNewPasskeysBody;

  /// No description provided for @whatsNewPhotoZoomBody.
  ///
  /// In en, this message translates to:
  /// **'Profile photos open full-size everywhere'**
  String get whatsNewPhotoZoomBody;

  /// No description provided for @whatsNewGradingTitle.
  ///
  /// In en, this message translates to:
  /// **'New daily grading'**
  String get whatsNewGradingTitle;

  /// No description provided for @whatsNewGradingBody.
  ///
  /// In en, this message translates to:
  /// **'Five categories, lateness now deducts points'**
  String get whatsNewGradingBody;

  /// No description provided for @myAnalysis.
  ///
  /// In en, this message translates to:
  /// **'My Analysis'**
  String get myAnalysis;

  /// No description provided for @tourReplay.
  ///
  /// In en, this message translates to:
  /// **'Take the tour'**
  String get tourReplay;

  /// No description provided for @tourSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get tourSkip;

  /// No description provided for @tourFinish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get tourFinish;

  /// No description provided for @tourProgress.
  ///
  /// In en, this message translates to:
  /// **'{current} of {total}'**
  String tourProgress(int current, int total);

  /// No description provided for @tourWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}!'**
  String tourWelcomeTitle(String name);

  /// No description provided for @tourWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Here\'s a one-minute look at the main parts of the app. You can skip it and take it again any time from your Profile.'**
  String get tourWelcomeBody;

  /// No description provided for @tourScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Your day at a glance'**
  String get tourScheduleTitle;

  /// No description provided for @tourScheduleBody.
  ///
  /// In en, this message translates to:
  /// **'Today\'s lessons and meetings, with the one in progress highlighted. Tap it to take attendance and grade the lesson.'**
  String get tourScheduleBody;

  /// No description provided for @tourUpdatesTitle.
  ///
  /// In en, this message translates to:
  /// **'Updates'**
  String get tourUpdatesTitle;

  /// No description provided for @tourUpdatesBody.
  ///
  /// In en, this message translates to:
  /// **'Your latest points, savings, announcements and upcoming events roll by here. Swipe sideways to flip through them.'**
  String get tourUpdatesBody;

  /// No description provided for @tourAppsTitle.
  ///
  /// In en, this message translates to:
  /// **'Your apps'**
  String get tourAppsTitle;

  /// No description provided for @tourAppsBody.
  ///
  /// In en, this message translates to:
  /// **'Every app you can use is here. Tap a tile to open it. Press and hold a tile to rearrange them; your order is saved.'**
  String get tourAppsBody;

  /// No description provided for @tourNotificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get tourNotificationsTitle;

  /// No description provided for @tourNotificationsBody.
  ///
  /// In en, this message translates to:
  /// **'New messages and updates for you land here.'**
  String get tourNotificationsBody;

  /// No description provided for @tourNavTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick navigation'**
  String get tourNavTitle;

  /// No description provided for @tourNavBody.
  ///
  /// In en, this message translates to:
  /// **'Your main apps are always one tap away at the bottom of the screen.'**
  String get tourNavBody;

  /// No description provided for @tourProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Your profile'**
  String get tourProfileTitle;

  /// No description provided for @tourProfileBody.
  ///
  /// In en, this message translates to:
  /// **'Settings, language, theme, suggestions and signing out. You can take this tour again from here.'**
  String get tourProfileBody;

  /// No description provided for @tourDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re all set!'**
  String get tourDoneTitle;

  /// No description provided for @tourDoneBody.
  ///
  /// In en, this message translates to:
  /// **'That\'s the tour. Anything new shows up in the Updates card on your Home.'**
  String get tourDoneBody;

  /// No description provided for @whatsNewCalendarTitle.
  ///
  /// In en, this message translates to:
  /// **'Calendar, analyses and more'**
  String get whatsNewCalendarTitle;

  /// No description provided for @whatsNewCalendarBody.
  ///
  /// In en, this message translates to:
  /// **'New on Home: Calendar, My Analysis, My Department for heads, and a guided tour.'**
  String get whatsNewCalendarBody;

  /// No description provided for @passkeySignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a passkey'**
  String get passkeySignIn;

  /// No description provided for @passkeyOfferTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in faster next time'**
  String get passkeyOfferTitle;

  /// No description provided for @passkeyOfferBody.
  ///
  /// In en, this message translates to:
  /// **'Add a passkey and next time sign in with Face ID, your fingerprint or your phone\'s passcode instead of a password.'**
  String get passkeyOfferBody;

  /// No description provided for @passkeyAdd.
  ///
  /// In en, this message translates to:
  /// **'Add a passkey'**
  String get passkeyAdd;

  /// No description provided for @passkeyNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get passkeyNotNow;

  /// No description provided for @passkeyAdded.
  ///
  /// In en, this message translates to:
  /// **'Passkey added'**
  String get passkeyAdded;

  /// No description provided for @passkeyAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the passkey. Try again later.'**
  String get passkeyAddFailed;

  /// No description provided for @passkeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Passkeys aren\'t available on this phone yet.'**
  String get passkeyUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ru', 'uz'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ru':
      return AppLocalizationsRu();
    case 'uz':
      return AppLocalizationsUz();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
