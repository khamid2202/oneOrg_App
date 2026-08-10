// ignore_for_file: file_names

import 'package:flutter/material.dart';

import 'package:one_org_staff/features/TimeTable/time_table_repository.dart';
import 'package:one_org_staff/features/auth/domain/auth_repository.dart';

class TimeTablePage extends StatefulWidget {
	const TimeTablePage({
		super.key,
		required this.loadTimetable,
	});

	final Future<List<TimetableLesson>> Function() loadTimetable;

	@override
	State<TimeTablePage> createState() => _TimeTablePageState();
}

class _TimeTablePageState extends State<TimeTablePage> {
	late Future<List<TimetableLesson>> _timetableFuture;

	@override
	void initState() {
		super.initState();
		_timetableFuture = widget.loadTimetable();
	}

	@override
	void didUpdateWidget(covariant TimeTablePage oldWidget) {
		super.didUpdateWidget(oldWidget);
		if (oldWidget.loadTimetable != widget.loadTimetable) {
			_timetableFuture = widget.loadTimetable();
		}
	}

	void _reload() {
		setState(() {
			_timetableFuture = widget.loadTimetable();
		});
	}

	@override
	Widget build(BuildContext context) {
		final theme = Theme.of(context);

		return Padding(
			padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Text(
						'Full timetable',
						style: theme.textTheme.headlineMedium?.copyWith(
							fontWeight: FontWeight.w800,
						),
					),
					const SizedBox(height: 8),
					Text(
						'Browse all class timetable entries grouped by day.',
						style: theme.textTheme.bodyLarge?.copyWith(
							color: _mutedTextColor(context),
						),
					),
					const SizedBox(height: 18),
					_TimetableToolbar(onRefresh: _reload),
					const SizedBox(height: 20),
					FutureBuilder<List<TimetableLesson>>(
						future: _timetableFuture,
						builder: (context, snapshot) {
							if (snapshot.connectionState != ConnectionState.done) {
								return const SizedBox(
									height: 280,
									child: Center(child: CircularProgressIndicator()),
								);
							}

							if (snapshot.hasError) {
								return _TimetableLoadError(
									message: 'Soon the content will appear',
									onRetry: _reload,
								);
							}

							final lessons = snapshot.data ?? const <TimetableLesson>[];
							if (lessons.isEmpty) {
								return const _EmptyTimetableState();
							}

							final sections = _buildSections(lessons);
							return Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									_TimetableSummaryCard(
										lessonCount: lessons.length,
										dayCount: sections.length,
									),
									const SizedBox(height: 18),
									for (final section in sections) ...[
										_TimetableDaySection(section: section),
										const SizedBox(height: 14),
									],
								],
							);
						},
					),
				],
			),
		);
	}

	List<_TimetableSection> _buildSections(List<TimetableLesson> lessons) {
		final grouped = <int, List<TimetableLesson>>{};
		final looseEntries = <TimetableLesson>[];

		for (final lesson in lessons) {
			final key = lesson.dayIndex;
			if (key == null) {
				looseEntries.add(lesson);
			} else {
				grouped.putIfAbsent(key, () => <TimetableLesson>[]).add(lesson);
			}
		}

		final sections = <_TimetableSection>[];
		final sortedKeys = grouped.keys.toList()..sort();
		for (final key in sortedKeys) {
			final items = grouped[key]!..sort(_compareLessons);
			sections.add(
				_TimetableSection(
					title: TimetableLesson.weekdayLabelFromIndex(key) ?? 'Day $key',
					lessons: items,
				),
			);
		}

		if (looseEntries.isNotEmpty) {
			looseEntries.sort(_compareLessons);
			sections.add(
				_TimetableSection(
					title: 'Other',
					lessons: looseEntries,
				),
			);
		}

		return sections;
	}

	int _compareLessons(TimetableLesson left, TimetableLesson right) {
		final timeIdComparison = (left.timeId ?? 999).compareTo(right.timeId ?? 999);
		if (timeIdComparison != 0) {
			return timeIdComparison;
		}

		final timeLabelComparison = left.timeLabel.compareTo(right.timeLabel);
		if (timeLabelComparison != 0) {
			return timeLabelComparison;
		}

		return left.title.compareTo(right.title);
	}

	Color _mutedTextColor(BuildContext context) {
		return Theme.of(context).brightness == Brightness.dark
				? const Color(0xFFB7C3D1)
				: const Color(0xFF5C738B);
	}
}

class _TimetableToolbar extends StatelessWidget {
	const _TimetableToolbar({required this.onRefresh});

	final VoidCallback onRefresh;

	@override
	Widget build(BuildContext context) {
		final isDarkMode = Theme.of(context).brightness == Brightness.dark;

		return Container(
			width: double.infinity,
			padding: const EdgeInsets.all(18),
			decoration: BoxDecoration(
				color: isDarkMode ? const Color(0xFF1A2430) : const Color(0xFFF4F7FB),
				borderRadius: BorderRadius.circular(24),
				border: Border.all(
					color: isDarkMode
							? const Color(0xFF273445)
							: const Color(0xFFD7E1EE),
				),
			),
			child: Row(
				children: [
					Expanded(
						child: Text(
							'All days and all class entries are shown in one weekly view.',
							style: Theme.of(context).textTheme.bodyLarge?.copyWith(
										color: isDarkMode
												? const Color(0xFFB7C3D1)
												: const Color(0xFF5C738B),
									),
						),
					),
					const SizedBox(width: 12),
					OutlinedButton.icon(
						onPressed: onRefresh,
						icon: const Icon(Icons.refresh_rounded),
						label: const Text('Refresh'),
					),
				],
			),
		);
	}
}

class _TimetableSummaryCard extends StatelessWidget {
	const _TimetableSummaryCard({
		required this.lessonCount,
		required this.dayCount,
	});

	final int lessonCount;
	final int dayCount;

	@override
	Widget build(BuildContext context) {
		final isDarkMode = Theme.of(context).brightness == Brightness.dark;

		return Container(
			width: double.infinity,
			padding: const EdgeInsets.all(20),
			decoration: BoxDecoration(
				gradient: isDarkMode
						? const LinearGradient(
								colors: [Color(0xFF183149), Color(0xFF102231)],
							)
						: const LinearGradient(
								colors: [Color(0xFFE8F3FF), Color(0xFFF8FBFF)],
							),
				borderRadius: BorderRadius.circular(24),
			),
			child: Row(
				children: [
					Container(
						width: 48,
						height: 48,
						decoration: BoxDecoration(
							color: const Color(0xFF64AFFF).withValues(alpha: 0.18),
							borderRadius: BorderRadius.circular(16),
						),
						child: const Icon(
							Icons.grid_view_rounded,
							color: Color(0xFF64AFFF),
						),
					),
					const SizedBox(width: 16),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									'$lessonCount timetable entries',
									style: Theme.of(context).textTheme.titleMedium?.copyWith(
												fontWeight: FontWeight.w700,
											),
								),
								const SizedBox(height: 4),
								Text(
									'Organized across $dayCount day${dayCount == 1 ? '' : 's'}',
									style: Theme.of(context).textTheme.bodyMedium?.copyWith(
												color: isDarkMode
														? const Color(0xFFB7C3D1)
														: const Color(0xFF5C738B),
											),
								),
							],
						),
					),
				],
			),
		);
	}
}

class _TimetableDaySection extends StatelessWidget {
	const _TimetableDaySection({required this.section});

	final _TimetableSection section;

	@override
	Widget build(BuildContext context) {
		final isDarkMode = Theme.of(context).brightness == Brightness.dark;

		return Container(
			width: double.infinity,
			padding: const EdgeInsets.all(18),
			decoration: BoxDecoration(
				color: isDarkMode ? const Color(0xFF1A2430) : const Color(0xFFF4F7FB),
				borderRadius: BorderRadius.circular(24),
				border: Border.all(
					color: isDarkMode
							? const Color(0xFF273445)
							: const Color(0xFFD7E1EE),
				),
			),
			child: Column(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Row(
						children: [
							Expanded(
								child: Text(
									section.title,
									style: Theme.of(context).textTheme.titleLarge?.copyWith(
												fontWeight: FontWeight.w800,
											),
								),
							),
							Text(
								'${section.lessons.length} item${section.lessons.length == 1 ? '' : 's'}',
								style: Theme.of(context).textTheme.labelLarge?.copyWith(
											color: isDarkMode
													? const Color(0xFF9DB0C1)
													: const Color(0xFF5C738B),
										),
							),
						],
					),
					const SizedBox(height: 14),
					for (var index = 0; index < section.lessons.length; index++) ...[
						_TimetableEntryCard(lesson: section.lessons[index]),
						if (index != section.lessons.length - 1) const SizedBox(height: 10),
					],
				],
			),
		);
	}
}

class _TimetableEntryCard extends StatelessWidget {
	const _TimetableEntryCard({required this.lesson});

	final TimetableLesson lesson;

	String? get _slotLabel {
		final timeId = lesson.timeId;
		if (timeId == null) {
			return null;
		}

		final slotLabel = 'Slot $timeId';
		if (lesson.timeLabel == slotLabel) {
			return null;
		}

		return slotLabel;
	}

	@override
	Widget build(BuildContext context) {
		final isDarkMode = Theme.of(context).brightness == Brightness.dark;
		final mutedColor =
				isDarkMode ? const Color(0xFF9DB0C1) : const Color(0xFF5C738B);

		return Container(
			width: double.infinity,
			padding: const EdgeInsets.all(16),
			decoration: BoxDecoration(
				color: isDarkMode ? const Color(0xFF223042) : Colors.white,
				borderRadius: BorderRadius.circular(20),
			),
			child: Row(
				crossAxisAlignment: CrossAxisAlignment.start,
				children: [
					Container(
						width: 86,
						padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
						decoration: BoxDecoration(
							color: const Color(0xFF64AFFF).withValues(alpha: 0.14),
							borderRadius: BorderRadius.circular(16),
						),
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							mainAxisSize: MainAxisSize.min,
							children: [
								Text(
									lesson.timeLabel,
									style: Theme.of(context).textTheme.labelLarge?.copyWith(
												color: const Color(0xFF64AFFF),
												fontWeight: FontWeight.w700,
											),
								),
								if (_slotLabel != null) ...[
									const SizedBox(height: 4),
									Text(
										_slotLabel!,
										style: Theme.of(context).textTheme.bodySmall?.copyWith(
													color: mutedColor,
												),
									),
								],
							],
						),
					),
					const SizedBox(width: 14),
					Expanded(
						child: Column(
							crossAxisAlignment: CrossAxisAlignment.start,
							children: [
								Text(
									lesson.title,
									style: Theme.of(context).textTheme.titleMedium?.copyWith(
												fontWeight: FontWeight.w800,
											),
								),
								if (lesson.subtitle != null) ...[
									const SizedBox(height: 6),
									Text(
										lesson.subtitle!,
										style: Theme.of(context).textTheme.bodyMedium?.copyWith(
													color: mutedColor,
												),
									),
								],
								const SizedBox(height: 10),
								Wrap(
									spacing: 8,
									runSpacing: 8,
									children: [
										if (lesson.room != null)
											_InfoChip(
												icon: Icons.meeting_room_outlined,
												label: lesson.room!,
											),
										_InfoChip(
											icon: lesson.isTextLesson
													? Icons.notes_rounded
													: Icons.menu_book_rounded,
											label: lesson.isTextLesson ? 'Text lesson' : 'Structured',
										),
									],
								),
							],
						),
					),
				],
			),
		);
	}
}

class _InfoChip extends StatelessWidget {
	const _InfoChip({
		required this.icon,
		required this.label,
	});

	final IconData icon;
	final String label;

	@override
	Widget build(BuildContext context) {
		final isDarkMode = Theme.of(context).brightness == Brightness.dark;

		return Container(
			padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
			decoration: BoxDecoration(
				color: isDarkMode ? const Color(0xFF1A2430) : const Color(0xFFF4F7FB),
				borderRadius: BorderRadius.circular(999),
				border: Border.all(
					color: isDarkMode
							? const Color(0xFF304154)
							: const Color(0xFFD7E1EE),
				),
			),
			child: Row(
				mainAxisSize: MainAxisSize.min,
				children: [
					Icon(icon, size: 16),
					const SizedBox(width: 6),
					Text(
						label,
						style: Theme.of(context).textTheme.labelLarge?.copyWith(
									fontWeight: FontWeight.w700,
								),
					),
				],
			),
		);
	}
}

class _EmptyTimetableState extends StatelessWidget {
	const _EmptyTimetableState();

	@override
	Widget build(BuildContext context) {
		final isDarkMode = Theme.of(context).brightness == Brightness.dark;

		return Container(
			width: double.infinity,
			padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
			decoration: BoxDecoration(
				color: isDarkMode ? const Color(0xFF1A2430) : const Color(0xFFF4F7FB),
				borderRadius: BorderRadius.circular(24),
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					const Icon(Icons.grid_off_rounded, size: 40),
					const SizedBox(height: 14),
					Text(
						'No timetable entries found',
						style: Theme.of(context).textTheme.titleLarge?.copyWith(
									fontWeight: FontWeight.w800,
								),
					),
					const SizedBox(height: 8),
					Text(
						'The weekly timetable is empty right now.',
						textAlign: TextAlign.center,
						style: Theme.of(context).textTheme.bodyLarge,
					),
				],
			),
		);
	}
}

class _TimetableLoadError extends StatelessWidget {
	const _TimetableLoadError({
		required this.message,
		required this.onRetry,
	});

	final String message;
	final VoidCallback onRetry;

	@override
	Widget build(BuildContext context) {
		return Container(
			width: double.infinity,
			padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
			decoration: BoxDecoration(
				color: Theme.of(context).brightness == Brightness.dark
						? const Color(0xFF1A2430)
						: const Color(0xFFF4F7FB),
				borderRadius: BorderRadius.circular(24),
			),
			child: Column(
				mainAxisSize: MainAxisSize.min,
				children: [
					const Icon(Icons.error_outline_rounded, size: 40),
					const SizedBox(height: 14),
					Text(
						message,
						textAlign: TextAlign.center,
						style: Theme.of(context).textTheme.bodyLarge,
					),
					const SizedBox(height: 16),
					OutlinedButton.icon(
						onPressed: onRetry,
						icon: const Icon(Icons.refresh_rounded),
						label: const Text('Retry'),
					),
				],
			),
		);
	}
}

class _TimetableSection {
	const _TimetableSection({
		required this.title,
		required this.lessons,
	});

	final String title;
	final List<TimetableLesson> lessons;
}
