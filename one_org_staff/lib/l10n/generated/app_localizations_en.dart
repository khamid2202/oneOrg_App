// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get language => 'Language';

  @override
  String get mySchedule => 'My Schedule';

  @override
  String get today => 'Today';

  @override
  String get retry => 'Retry';

  @override
  String get loadLessonsFailed => 'Failed to fetch lessons. Please try again.';

  @override
  String noLessonsOn(String date) {
    return 'You have no lessons on $date.';
  }

  @override
  String nowFor(String duration) {
    return 'Now · $duration';
  }

  @override
  String durationMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String durationHours(int hours) {
    return '${hours}h';
  }

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '${hours}h ${minutes}m';
  }

  @override
  String get substitution => 'Substitution';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get meeting => 'Meeting';

  @override
  String get untitled => 'Untitled';

  @override
  String periodShort(int number) {
    return 'P$number';
  }

  @override
  String get noLessonRecord =>
      'This date has no lesson record to score: it\'s before the published timetable\'s start date, a holiday, or not generated yet.';

  @override
  String get attendance => 'Attendance';

  @override
  String get scores => 'Scores';

  @override
  String get present => 'Present';

  @override
  String get late => 'Late';

  @override
  String get absent => 'Absent';

  @override
  String get excused => 'Excused';

  @override
  String get presentShort => 'P';

  @override
  String get lateShort => 'L';

  @override
  String get absentShort => 'A';

  @override
  String get excusedShort => 'E';

  @override
  String minutesShort(int minutes) {
    return '${minutes}m';
  }

  @override
  String get minutesHint => 'min';

  @override
  String get materials => 'Materials';

  @override
  String get homeworkDone => 'HW done';

  @override
  String get homework => 'HW right';

  @override
  String get activity => 'Activity';

  @override
  String get notes => 'Notes';

  @override
  String get next => 'Next';

  @override
  String get saveAndNext => 'Save & next';

  @override
  String get save => 'Save';

  @override
  String get skip => 'Skip';

  @override
  String get saved => 'Saved';

  @override
  String get attendanceSaved => 'Attendance saved';

  @override
  String get scoresSaved => 'Scores saved';

  @override
  String studentsCount(int count) {
    return '$count students';
  }

  @override
  String addMinutesForLate(int count) {
    return 'Add minutes for $count late';
  }

  @override
  String needFixing(int count) {
    return '$count need fixing';
  }

  @override
  String toSave(int count) {
    return '$count to save';
  }

  @override
  String get fixHighlightedRows => 'Fix the highlighted rows first';

  @override
  String get lessonCancelledBanner =>
      'This lesson was cancelled; its scores are read-only.';

  @override
  String lessonCancelledReasonBanner(String reason) {
    return 'This lesson was cancelled ($reason); its scores are read-only.';
  }

  @override
  String get windowClosedBanner =>
      'Scores can be changed for 3 days after the lesson, and no later than Saturday 08:00. Ask an admin to correct this lesson.';

  @override
  String get noStudents =>
      'No students are enrolled in this class on this date.';

  @override
  String get unsavedTitle => 'Unsaved changes';

  @override
  String get unsavedBody => 'Leave without saving your changes?';

  @override
  String get stay => 'Stay';

  @override
  String get leave => 'Leave';

  @override
  String get commentHint => 'Comment';

  @override
  String get whyBelow40 => 'Why below 40? (required)';

  @override
  String get noteOptional => 'Note (optional with a reason)';

  @override
  String get foldAll => 'Fold all';

  @override
  String get unfoldAll => 'Unfold all';

  @override
  String get uploads => 'Uploads';

  @override
  String get tryNow => 'Try now';

  @override
  String notAccepted(String reason) {
    return 'Not accepted: $reason';
  }

  @override
  String waitingForConnection(int tries) {
    return 'Waiting for a connection ($tries tries)';
  }

  @override
  String get discard => 'Discard';

  @override
  String get behavior => 'Behavior';

  @override
  String waitingToUpload(int count) {
    return '$count waiting to upload';
  }

  @override
  String notAcceptedCount(int count) {
    return '$count not accepted';
  }

  @override
  String signOutUnsent(int count) {
    return '$count saves are still on this phone and will be lost if you sign out.';
  }

  @override
  String get home => 'Home';

  @override
  String get schedule => 'Schedule';

  @override
  String get classShort => 'Class';

  @override
  String get myClass => 'My Class';

  @override
  String get grades => 'Grades';

  @override
  String get exams => 'Exams';

  @override
  String get timetable => 'Timetable';

  @override
  String get rewards => 'Rewards';

  @override
  String get colleagues => 'Colleagues';

  @override
  String get pointReport => 'Point Report';

  @override
  String get profile => 'Profile';

  @override
  String hiName(String name) {
    return 'Hi, $name';
  }

  @override
  String lessonsExamsCount(int lessons, int exams) {
    return 'Lessons: $lessons · Exams: $exams';
  }

  @override
  String get loadFailed => 'Couldn\'t load. Check your connection.';

  @override
  String get noClassesYet => 'No classes assigned to you yet.';

  @override
  String get noGradesYet => 'No grades yet.';

  @override
  String get all => 'All';

  @override
  String get student => 'Student';

  @override
  String get averageShort => 'Avg';

  @override
  String get examsShort => 'Exams';

  @override
  String get reportStudent => 'Report Student';

  @override
  String get reportShort => 'Report';

  @override
  String get markTab => 'Mark';

  @override
  String get historyTab => 'History';

  @override
  String get statisticsTab => 'Stats';

  @override
  String get stepWho => 'Who';

  @override
  String get stepWhatKind => 'What kind';

  @override
  String get stepWhy => 'Why';

  @override
  String get searchAnyStudent => 'Search any student…';

  @override
  String get otherClass => 'Other class…';

  @override
  String get mine => 'mine';

  @override
  String get selectAll => 'Select all';

  @override
  String get unselectAll => 'Unselect all';

  @override
  String get tapStudentsFirst => 'Tap the students first';

  @override
  String nextWho(String who) {
    return 'Next · $who';
  }

  @override
  String get pickOneAbove => 'Pick one above';

  @override
  String get pickReasonOrComment => 'Pick a reason or write a comment';

  @override
  String saveForWho(String who) {
    return 'Save for $who';
  }

  @override
  String savedForWho(String who) {
    return 'Saved for $who';
  }

  @override
  String get seeInHistory => 'See it in history';

  @override
  String get markMore => 'Mark more';

  @override
  String markMoreIn(String cls) {
    return 'Mark more in $cls';
  }

  @override
  String get back => 'Back';

  @override
  String get positive => 'Positive';

  @override
  String get needsAttention => 'Needs attention';

  @override
  String get positiveDetail => 'Something worth praising';

  @override
  String get negativeDetail => 'Something to work on';

  @override
  String get addCommentOptional => 'Add a comment (optional)';

  @override
  String get noStudentNamed => 'No student with that name.';

  @override
  String get noStudentsInClass => 'No students in this class.';

  @override
  String get loadingStudents => 'Loading students…';

  @override
  String acrossSchool(int count) {
    return '$count across the school';
  }

  @override
  String get studentOrClass => 'Student or class';

  @override
  String get noFilterMatches => 'Nothing matches these filters.';

  @override
  String get noBehaviorMarks => 'No behavior marks yet.';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get total => 'Total';

  @override
  String get byClass => 'By class';

  @override
  String get byWeek => 'By week';

  @override
  String get commonReasons => 'Common reasons';

  @override
  String get noMarksForPeriod => 'No marks for this period.';

  @override
  String get myPlan => 'My Plan';

  @override
  String get myPoints => 'My Points';

  @override
  String get myFundings => 'My Fundings';

  @override
  String get teachingTools => 'Teaching Tools';

  @override
  String get teachingShort => 'Teaching';

  @override
  String get thisMonth => 'This month';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get thisYear => 'This year';

  @override
  String get moreFilters => 'More filters';

  @override
  String get allCategories => 'All categories';

  @override
  String historyCount(int count) {
    return 'History ($count)';
  }

  @override
  String inThisPeriod(String amount) {
    return '$amount in this period';
  }

  @override
  String get noPointsYet =>
      'Points you\'re awarded or that are deducted will show up here.';

  @override
  String get nothingInPeriod => 'Nothing in this period.';

  @override
  String get noSavingsYet => 'Your savings will show up here.';

  @override
  String get showAmounts => 'Show amounts';

  @override
  String get hideAmounts => 'Hide amounts';

  @override
  String get currencySom => 'UZS';

  @override
  String get received => 'Received';

  @override
  String get withdrawn => 'Withdrawn';

  @override
  String get balance => 'Balance';

  @override
  String get addMilestone => 'Add milestone';

  @override
  String get editMilestone => 'Edit milestone';

  @override
  String get milestones => 'Milestones';

  @override
  String get noPlanYet =>
      'No plan yet. Break the year into the parts you\'ll work through and mark each one off as you go.';

  @override
  String get noMilestonesWithStatus => 'Nothing with that status.';

  @override
  String get planNotStarted => 'Not started';

  @override
  String get planInProgress => 'In progress';

  @override
  String get planDone => 'Done';

  @override
  String get planPostponed => 'Postponed';

  @override
  String get planCancelled => 'Cancelled';

  @override
  String get overdue => 'Overdue';

  @override
  String get priority => 'Priority';

  @override
  String get priorityLow => 'Low';

  @override
  String get priorityMedium => 'Medium';

  @override
  String get priorityHigh => 'High';

  @override
  String get priorityUrgent => 'Urgent';

  @override
  String get status => 'Status';

  @override
  String get category => 'Category';

  @override
  String get categoryCurriculum => 'Curriculum';

  @override
  String get categoryLesson => 'Lesson';

  @override
  String get categoryExam => 'Exam';

  @override
  String get categoryMeeting => 'Meeting';

  @override
  String get categoryAdministrative => 'Administrative';

  @override
  String get categoryPersonal => 'Personal';

  @override
  String get categoryGeneral => 'General';

  @override
  String get starts => 'Starts';

  @override
  String get ends => 'Ends';

  @override
  String get milestoneTitleHint => 'Title, e.g. Term 1 algebra unit';

  @override
  String get addFiles => 'Add files';

  @override
  String fileTooBig(String name) {
    return '$name is larger than 10 MB';
  }

  @override
  String get milestoneNeedsTitle => 'Give the milestone a title';

  @override
  String get endBeforeStart => 'The end date can\'t come before the start date';

  @override
  String get milestoneAdded => 'Milestone added';

  @override
  String get milestoneUpdated => 'Milestone updated';

  @override
  String get milestoneDeleted => 'Milestone deleted';

  @override
  String get couldNotSaveMilestone => 'Couldn\'t save the milestone';

  @override
  String get couldNotDeleteMilestone => 'Couldn\'t delete the milestone';

  @override
  String get planStatusFailed => 'Couldn\'t update the status';

  @override
  String get deleteMilestoneTitle => 'Delete this milestone?';

  @override
  String deleteMilestoneBody(String agenda) {
    return '\"$agenda\" and its attachments will be removed. This can\'t be undone.';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get soon => 'Soon';

  @override
  String get teamShuffle => 'Team Shuffle';

  @override
  String get namePicker => 'Name Picker';

  @override
  String get timer => 'Timer';

  @override
  String get participation => 'Participation';

  @override
  String get homeworkCheck => 'Homework Check';

  @override
  String get balancedTeams => 'Balanced Teams';

  @override
  String get seatingPlan => 'Seating Plan';

  @override
  String get done => 'Done';

  @override
  String get absentQuestion => 'Absent?';

  @override
  String get startOver => 'Start over';

  @override
  String get fewerTeams => 'Fewer teams';

  @override
  String get moreTeams => 'More teams';

  @override
  String get roles => 'Roles';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get again => 'Again';

  @override
  String get teamRed => 'Red';

  @override
  String get teamBlue => 'Blue';

  @override
  String get teamGreen => 'Green';

  @override
  String get teamYellow => 'Yellow';

  @override
  String get teamPurple => 'Purple';

  @override
  String get teamOrange => 'Orange';

  @override
  String get teamPink => 'Pink';

  @override
  String get teamTeal => 'Teal';

  @override
  String get roleLeader => 'Leader';

  @override
  String get roleTimekeeper => 'Timekeeper';

  @override
  String get roleRecorder => 'Recorder';

  @override
  String get roleReporter => 'Reporter';

  @override
  String get roleChecker => 'Checker';

  @override
  String get roleEncourager => 'Encourager';

  @override
  String get roleMaterials => 'Materials';

  @override
  String get roleQuestioner => 'Questioner';

  @override
  String get roleHelper => 'Helper';

  @override
  String get oneMinuteLess => 'One minute less';

  @override
  String get oneMinuteMore => 'One minute more';

  @override
  String get pause => 'Pause';

  @override
  String get start => 'Start';

  @override
  String get reset => 'Reset';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get comingSoonBody => 'This part of the app isn\'t ready yet.';

  @override
  String get search => 'Search';

  @override
  String get notifications => 'Notifications';

  @override
  String get searchHint => 'Pages, students, codes…';

  @override
  String get searchPagesHint => 'Search the app…';

  @override
  String get searchSuggested => 'Suggested';

  @override
  String get searchPages => 'Pages';

  @override
  String get searchPeople => 'People';

  @override
  String searchFound(int count) {
    return '$count found';
  }

  @override
  String searchMinChars(int count) {
    return 'Type $count letters to search people';
  }

  @override
  String searchNothing(String query) {
    return 'Nothing found for “$query”';
  }

  @override
  String get searchNothingBody =>
      'Try another spelling, a student code or a page name.';

  @override
  String get searchNothingPagesBody => 'Try another word for the page.';

  @override
  String get searchShowMore => 'Show more';

  @override
  String get searchLeft => 'Left';

  @override
  String searchGrade(int grade) {
    return 'Grade $grade';
  }

  @override
  String get searchFailed => 'Couldn\'t search people.';

  @override
  String colleaguesActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active colleagues',
      one: '1 active colleague',
    );
    return '$_temp0';
  }

  @override
  String get colleaguesNone => 'No colleagues found.';

  @override
  String get colleaguesNoneMatching => 'No colleagues match your search.';

  @override
  String get colleaguesNoPhone => 'No phone number';

  @override
  String colleaguesCall(String name) {
    return 'Call $name';
  }

  @override
  String colleaguesMessage(String name) {
    return 'Message $name';
  }

  @override
  String get colleaguesCopied => 'Number copied';

  @override
  String get colleaguesCantCall => 'Couldn\'t open the phone app.';

  @override
  String get colleaguesLoadFailed => 'Couldn\'t load colleagues.';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String pointsFor(String date) {
    return 'For $date';
  }

  @override
  String get pointsEdited => 'edited';

  @override
  String get pointsRefreshFailed => 'Couldn\'t refresh your points.';

  @override
  String get pointsWiderPeriod => 'Try a wider period.';

  @override
  String get colleaguesSwipeCall => 'Call';

  @override
  String get colleaguesSwipeMessage => 'Message';

  @override
  String get classStudentsTab => 'Students';

  @override
  String get classGradesTab => 'Grades';

  @override
  String get classBehaviorTab => 'Behavior';

  @override
  String classStudentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count students',
      one: '1 student',
    );
    return '$_temp0';
  }

  @override
  String get classLeft => 'Left';

  @override
  String get classPresent => 'Present';

  @override
  String get classContacts => 'Contacts';

  @override
  String get classNoContacts => 'No contacts yet.';

  @override
  String get classEditContacts => 'Edit contacts';

  @override
  String get classNoStudents => 'No students in this class.';

  @override
  String get classNoHomeroom => 'No class assigned';

  @override
  String get classNoHomeroomBody =>
      'You aren\'t the homeroom teacher of a class this year.';

  @override
  String get classGradesNone => 'No grades yet';

  @override
  String get classGradesFailed => 'Couldn\'t load grades.';

  @override
  String get classDaily => 'Daily';

  @override
  String get classGraded => 'Graded';

  @override
  String get classCatAttend => 'Attend';

  @override
  String get classCatBooks => 'Books';

  @override
  String get classCatHomework => 'HW';

  @override
  String get classCatActive => 'Active';

  @override
  String get classCatNotes => 'Notes';

  @override
  String get classBehaviorFailed => 'Couldn\'t load behavior.';

  @override
  String get classPositive => 'Positive';

  @override
  String get classNeedsAttention => 'Needs attention';

  @override
  String get classMark => 'Mark';

  @override
  String get classNoMarks => 'No marks yet';

  @override
  String classAllMarks(int count) {
    return 'All $count';
  }

  @override
  String notMarkedCount(int count) {
    return '$count not marked';
  }

  @override
  String get allMarked => 'All marked';

  @override
  String get notMarked => 'not marked';

  @override
  String notFinished(int count) {
    return '$count not finished';
  }

  @override
  String scoreEveryCategory(int count) {
    return 'Score every category for $count student(s) first';
  }

  @override
  String get oldGradingLesson =>
      'this lesson was marked before the new grading, so it uses the old categories';
}
