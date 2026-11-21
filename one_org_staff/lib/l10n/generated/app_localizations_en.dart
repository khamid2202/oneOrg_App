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

  @override
  String get profileAccount => 'Account';

  @override
  String get profileApp => 'App';

  @override
  String get profileEmail => 'Email';

  @override
  String get profilePhone => 'Phone';

  @override
  String get profilePassword => 'Password';

  @override
  String get profileSystem => 'System';

  @override
  String get profileSystemHint => 'Language, color, dark mode';

  @override
  String get profileSuggestions => 'Suggestions';

  @override
  String get profileLogOut => 'Log out';

  @override
  String get profileNotSet => 'Not set';

  @override
  String get profileContactTitle => 'Contact details';

  @override
  String get profileInvalidEmail => 'Enter a valid email address';

  @override
  String get profileInvalidPhone => 'Enter a valid phone number';

  @override
  String get profileContactSaved => 'Contact details updated';

  @override
  String get profileContactFailed => 'Couldn\'t update contact details';

  @override
  String get suggestionsLead =>
      'Ideas, problems, questions — we read every one.';

  @override
  String get suggestionsPrompt => 'What should we improve?';

  @override
  String get suggestionsHint => 'Type your suggestion…';

  @override
  String get suggestionsAnonymous => 'Anonymous';

  @override
  String get suggestionsSend => 'Send';

  @override
  String get suggestionsSentButton => 'Sent';

  @override
  String get suggestionsSent => 'Sent — thank you!';

  @override
  String get suggestionsFailed => 'Could not send. Try again.';

  @override
  String get edit => 'Edit';

  @override
  String get calendar => 'Calendar';

  @override
  String get calToday => 'Today';

  @override
  String get calMonthView => 'Month';

  @override
  String get calScheduleView => 'Schedule';

  @override
  String get calNewEvent => 'New event';

  @override
  String get calEditEvent => 'Edit event';

  @override
  String get calEvents => 'Events';

  @override
  String get calHolidays => 'Holidays';

  @override
  String get calTerms => 'Terms';

  @override
  String get calExams => 'Exams';

  @override
  String get calAllEvents => 'All events';

  @override
  String get calNothingOnDay => 'Nothing on this day';

  @override
  String get calEvent => 'Event';

  @override
  String get calHoliday => 'Holiday';

  @override
  String get calTermStarts => 'Term starts';

  @override
  String get calTermEnds => 'Term ends';

  @override
  String get calExamPeriod => 'Exam period';

  @override
  String get calAllDay => 'All day';

  @override
  String get calCancelled => 'Cancelled';

  @override
  String get calDraft => 'Draft';

  @override
  String get calCancelEvent => 'Cancel event';

  @override
  String get calCancelEventQ => 'Cancel this event?';

  @override
  String get calDeleteEventQ => 'Delete this event?';

  @override
  String get calEventCancelled => 'Event cancelled';

  @override
  String get calEventDeleted => 'Event deleted';

  @override
  String get calChangeFailed => 'Couldn\'t save the change';

  @override
  String get calTitle => 'Title';

  @override
  String get calTitleRequired => 'Enter a title';

  @override
  String get calCategory => 'Category';

  @override
  String get calLocation => 'Location';

  @override
  String get calDescription => 'Description';

  @override
  String get calAudience => 'Who sees it';

  @override
  String get calAddAudience => 'Add';

  @override
  String get calAllStaff => 'All staff';

  @override
  String get calAllStudents => 'All students';

  @override
  String get calGrade => 'Grade';

  @override
  String get calClass => 'Class';

  @override
  String get calRole => 'Role';

  @override
  String get calDepartment => 'Dept';

  @override
  String get calSaveAsDraft => 'Save as draft';

  @override
  String get calNotify => 'Send a notification';

  @override
  String get calCatGeneral => 'General';

  @override
  String get calCatCeremony => 'Ceremony';

  @override
  String get calCatParentMeeting => 'Parent meeting';

  @override
  String get calCatTrip => 'Trip';

  @override
  String get calCatSports => 'Sports';

  @override
  String get calCatCompetition => 'Competition';

  @override
  String get calCatDeadline => 'Deadline';

  @override
  String get calCatStaff => 'Staff';

  @override
  String get calCatOther => 'Other';

  @override
  String get myLessonAnalysis => 'Lesson analysis results';

  @override
  String get myAnalysisShort => 'My Analysis';

  @override
  String get lessonAnalysis => 'Lesson Analysis';

  @override
  String get laNoneYet =>
      'No analyses yet. When one of your lessons is analysed, the results and feedback show up here.';

  @override
  String get laTotalPoints => 'Total points';

  @override
  String get laThisMonth => 'This month';

  @override
  String get laLastMonth => 'Last month';

  @override
  String get laAllTime => 'All time';

  @override
  String get laAnalyses => 'Analyses';

  @override
  String get laLatest => 'Latest';

  @override
  String laNotesCount(int count) {
    return '$count notes';
  }

  @override
  String get laNoNotes => 'No notes';

  @override
  String get laMyDepartment => 'My department';

  @override
  String laAnalysedOf(int analysed, int total) {
    return '$analysed of $total teachers analysed';
  }

  @override
  String laAnalysesCount(int count) {
    return '$count analyses';
  }

  @override
  String get laNotAnalysed => 'Not analysed yet';

  @override
  String get laSortLast => 'Last analysed';

  @override
  String get laSortMost => 'Most points';

  @override
  String get laSortLeast => 'Fewest points';

  @override
  String get laSortName => 'Name';

  @override
  String get laNewAnalysis => 'New analysis';

  @override
  String get laEditAnalysis => 'Edit analysis';

  @override
  String get laDeleteQ => 'Delete this analysis?';

  @override
  String get laDeleteBody => 'Its points are taken back from the teacher.';

  @override
  String get laDeleted => 'Analysis deleted';

  @override
  String get laTeacher => 'Teacher';

  @override
  String get laLesson => 'Lesson';

  @override
  String get laNoLessons =>
      'No lessons in the last 60 days that can be analysed.';

  @override
  String get laAnalysed => 'analysed';

  @override
  String get laPoints => 'Points';

  @override
  String get laNotes => 'Notes';

  @override
  String get laChooseTeacher => 'Choose the teacher';

  @override
  String get laChooseLesson => 'Choose the lesson';

  @override
  String get laPointsWhole => 'Points must be a whole number';

  @override
  String get laSaved => 'Saved';

  @override
  String get laSaveFailed => 'Couldn\'t save the analysis';

  @override
  String get myDepartment => 'My Department';

  @override
  String get deptNone => 'You don\'t lead a department.';

  @override
  String get deptHead => 'Head';

  @override
  String get deptDeputy => 'Deputy';

  @override
  String deptCounts(int subjects, int members) {
    return '$subjects subjects · $members members';
  }

  @override
  String get deptLessons => 'Lessons';

  @override
  String get deptAttendanceTaken => 'Attendance taken';

  @override
  String get deptGradesEntered => 'Grades entered';

  @override
  String get deptGrades => 'Grades';

  @override
  String get deptAvgGrade => 'Avg grade';

  @override
  String get deptAttendance => 'Attendance';

  @override
  String get deptExamAvg => 'Exam avg';

  @override
  String get deptKpi => 'KPI';

  @override
  String get deptTeachers => 'Teachers';

  @override
  String get deptSubjects => 'Subjects';

  @override
  String get deptClasses => 'Classes';

  @override
  String get deptAllClasses => 'All classes';

  @override
  String get cashier => 'Cashier';

  @override
  String get cashReview => 'Behaviour marks with no reason';

  @override
  String get cashSync => 'Sync grades';

  @override
  String get cashSyncFailed => 'Sync failed';

  @override
  String cashSyncedThrough(String date) {
    return 'Synced through $date';
  }

  @override
  String get cashClasses => 'Classes';

  @override
  String get cashRanking => 'School ranking';

  @override
  String get cashSearch => 'Student name';

  @override
  String get cashAmount => 'Amount';

  @override
  String get cashNote => 'Note';

  @override
  String get cashSpend => 'Spend';

  @override
  String get cashAdd => 'Add';

  @override
  String get cashResetQ => 'Set this balance to \$0?';

  @override
  String get cashResetZero => 'Reset to \$0';

  @override
  String get cashHistory => 'History';

  @override
  String get cashNoHistory => 'No history yet';

  @override
  String get attendanceCheck => 'Attendance';

  @override
  String get attNotMarked => 'Not marked';

  @override
  String get attOnNow => 'On now';

  @override
  String get attMarked => 'Marked';

  @override
  String get attLater => 'Later';

  @override
  String get attNoStudents => 'No students';

  @override
  String get attOnlyMissing => 'Only classes with unmarked lessons';

  @override
  String get attNoLessons => 'No lessons on this day';

  @override
  String get attAbsent => 'Absent';

  @override
  String get attLate => 'Late';

  @override
  String get attStatistics => 'Attendance statistics';

  @override
  String get attThisWeek => 'This week';

  @override
  String get attThisMonth => 'This month';

  @override
  String get attAttendanceRate => 'Attendance rate';

  @override
  String get attPresent => 'Present';

  @override
  String get attExcused => 'Excused';

  @override
  String get attByClass => 'By class';

  @override
  String get attByStudent => 'By student';

  @override
  String get attNoMarks => 'No attendance marks in this period';

  @override
  String get substitutions => 'Substitution';

  @override
  String get subNewAbsence => 'New absence';

  @override
  String get subNone => 'No substitutions in these two weeks';

  @override
  String get subNoLessonsYet =>
      'No lessons arranged yet — tap the absence to cover its lessons.';

  @override
  String subLessonsCount(int count) {
    return '$count lessons';
  }

  @override
  String get subRemove => 'Remove';

  @override
  String get subRemoveQ => 'Remove substitution?';

  @override
  String subRemoveBody(String lesson, String time) {
    return '$lesson at $time goes back to its original teacher. Nobody is notified.';
  }

  @override
  String get subRemoved => 'Substitution removed';

  @override
  String get subCover => 'Cover';

  @override
  String get subMerge => 'Merge';

  @override
  String get subCancel => 'Cancel';

  @override
  String get subNext => 'Next';

  @override
  String get subReasonSick => 'Sick';

  @override
  String get subReasonPersonal => 'Personal';

  @override
  String get subReasonTrip => 'Business trip';

  @override
  String get subReasonTraining => 'Training';

  @override
  String subCoverFor(String name) {
    return 'Cover for $name';
  }

  @override
  String get subNoAffected => 'This absence has no lessons.';

  @override
  String get subArranged => 'Already arranged';

  @override
  String get subPickEach => 'Pick a substitute or a lesson for each one';

  @override
  String get subSaved => 'Covers saved';

  @override
  String get subBusy => 'busy';

  @override
  String get subAbsent => 'absent';

  @override
  String get subUnavailable => 'unavailable';

  @override
  String get subSubject => 'subject';

  @override
  String get subKnowsClass => 'knows class';

  @override
  String subCoversMonth(int count) {
    return '$count covers/mo';
  }

  @override
  String get subSubstitute => 'Substitute';

  @override
  String get subMergeWith => 'Merge with';

  @override
  String get subAssignAnyway => 'Assign anyway';

  @override
  String get staffPoints => 'Staff Points';

  @override
  String get spAward => 'Award points';

  @override
  String get spAwardShort => 'Award';

  @override
  String get spDeduct => 'Deduct';

  @override
  String get spThisWeek => 'This week';

  @override
  String get spThisYear => 'This year';

  @override
  String get spChooseRecipients => 'Choose who';

  @override
  String get spAllTeachers => 'All teachers';

  @override
  String get spNoCategory => 'No category';

  @override
  String get spNoteRequired => 'Write a note';

  @override
  String spSaved(int count) {
    return 'Saved for $count';
  }

  @override
  String spSomeFailed(int count) {
    return '$count couldn\'t be saved';
  }

  @override
  String get fundings => 'Fundings';

  @override
  String get fundNew => 'New funding';

  @override
  String get fundNone => 'No savings yet';

  @override
  String get fundDeposits => 'Deposits';

  @override
  String get fundWithdrawals => 'Withdrawals';

  @override
  String get fundBalance => 'Balance';

  @override
  String get fundDeposit => 'Deposit';

  @override
  String get fundWithdrawal => 'Withdrawal';

  @override
  String get fundPerson => 'Person';

  @override
  String get fundAmountPositive => 'Enter an amount above zero';

  @override
  String get lunchDuty => 'Lunch duty';

  @override
  String get tagLab => 'Lab lesson';

  @override
  String get tagAfter => 'After-school lesson';

  @override
  String get updTitle => 'Updates';

  @override
  String get updNothingNew => 'Nothing new this week';

  @override
  String get updJustNow => 'just now';

  @override
  String updMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String updHoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String get updYesterday => 'yesterday';

  @override
  String updDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String updPoints(String points) {
    return '$points points';
  }

  @override
  String updTakenFrom(String name) {
    return 'Taken from $name';
  }

  @override
  String updAddedTo(String name) {
    return 'Added to $name';
  }

  @override
  String get updUpcomingEvent => 'Coming up';

  @override
  String get updTomorrow => 'tomorrow';

  @override
  String get dombitTooltip => 'Dombit \$ PDF for last week';

  @override
  String get dombitFailed => 'Could not make the PDF';

  @override
  String get updates => 'Updates';

  @override
  String get whatsNewPhotoZoomTitle => 'Tap a photo to enlarge it';

  @override
  String get whatsNewAttendanceTitle => 'Attendance statistics';

  @override
  String get whatsNewAttendanceBody => 'Attendance rates by class and student';

  @override
  String get whatsNewPasskeysTitle => 'Sign in with a passkey';

  @override
  String get whatsNewPasskeysBody =>
      'Use your fingerprint or face instead of a password';

  @override
  String get whatsNewPhotoZoomBody =>
      'Profile photos open full-size everywhere';

  @override
  String get whatsNewGradingTitle => 'New daily grading';

  @override
  String get whatsNewGradingBody =>
      'Five categories, lateness now deducts points';

  @override
  String get myAnalysis => 'My Analysis';

  @override
  String get tourReplay => 'Take the tour';

  @override
  String get tourSkip => 'Skip';

  @override
  String get tourFinish => 'Finish';

  @override
  String tourProgress(int current, int total) {
    return '$current of $total';
  }

  @override
  String tourWelcomeTitle(String name) {
    return 'Welcome, $name!';
  }

  @override
  String get tourWelcomeBody =>
      'Here\'s a one-minute look at the main parts of the app. You can skip it and take it again any time from your Profile.';

  @override
  String get tourScheduleTitle => 'Your day at a glance';

  @override
  String get tourScheduleBody =>
      'Today\'s lessons and meetings, with the one in progress highlighted. Tap it to take attendance and grade the lesson.';

  @override
  String get tourUpdatesTitle => 'Updates';

  @override
  String get tourUpdatesBody =>
      'Your latest points, savings, announcements and upcoming events roll by here. Swipe sideways to flip through them.';

  @override
  String get tourAppsTitle => 'Your apps';

  @override
  String get tourAppsBody =>
      'Every app you can use is here. Tap a tile to open it. Press and hold a tile to rearrange them; your order is saved.';

  @override
  String get tourNotificationsTitle => 'Notifications';

  @override
  String get tourNotificationsBody =>
      'New messages and updates for you land here.';

  @override
  String get tourNavTitle => 'Quick navigation';

  @override
  String get tourNavBody =>
      'Your main apps are always one tap away at the bottom of the screen.';

  @override
  String get tourProfileTitle => 'Your profile';

  @override
  String get tourProfileBody =>
      'Settings, language, theme, suggestions and signing out. You can take this tour again from here.';

  @override
  String get tourDoneTitle => 'You\'re all set!';

  @override
  String get tourDoneBody =>
      'That\'s the tour. Anything new shows up in the Updates card on your Home.';

  @override
  String get whatsNewCalendarTitle => 'Calendar, analyses and more';

  @override
  String get whatsNewCalendarBody =>
      'New on Home: Calendar, My Analysis, My Department for heads, and a guided tour.';

  @override
  String get passkeySignIn => 'Sign in with a passkey';

  @override
  String get passkeyOfferTitle => 'Sign in faster next time';

  @override
  String get passkeyOfferBody =>
      'Add a passkey and next time sign in with Face ID, your fingerprint or your phone\'s passcode instead of a password.';

  @override
  String get passkeyAdd => 'Add a passkey';

  @override
  String get passkeyNotNow => 'Not now';

  @override
  String get passkeyAdded => 'Passkey added';

  @override
  String get passkeyAddFailed => 'Couldn\'t add the passkey. Try again later.';

  @override
  String get passkeyUnavailable =>
      'Passkeys aren\'t available on this phone yet.';
}
