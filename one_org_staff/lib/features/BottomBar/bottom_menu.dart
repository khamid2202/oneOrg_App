import 'dart:ui';

import 'package:flutter/material.dart';

class BottomMenuItem {
	const BottomMenuItem({
		required this.label,
		required this.icon,
	});

	final String label;
	final IconData icon;
}

class BottomMenu extends StatelessWidget {
	const BottomMenu({
		super.key,
		required this.items,
		required this.selectedIndex,
		required this.onSelected,
	});

	final List<BottomMenuItem> items;
	final int selectedIndex;
	final ValueChanged<int> onSelected;

	@override
	Widget build(BuildContext context) {
		return SafeArea(
			top: false,
			minimum: const EdgeInsets.fromLTRB(16, 0, 16, 20),
			child: Align(
				alignment: Alignment.bottomCenter,
				heightFactor: 1,
				child: ConstrainedBox(
					constraints: const BoxConstraints(maxWidth: 760),
					child: ClipRRect(
						borderRadius: BorderRadius.circular(40),
						child: BackdropFilter(
							filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
							child: Container(
								padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
								decoration: BoxDecoration(
									gradient: const LinearGradient(
										begin: Alignment.topCenter,
										end: Alignment.bottomCenter,
										colors: [
											Color(0xCC2A2F38),
											Color(0xB31B1F26),
										],
									),
									borderRadius: BorderRadius.circular(40),
									border: Border.all(
										color: const Color(0x40FFFFFF),
									),
									boxShadow: const [
										BoxShadow(
											color: Color(0x3D000000),
											blurRadius: 28,
											offset: Offset(0, 16),
										),
										BoxShadow(
											color: Color(0x12000000),
											blurRadius: 3,
											offset: Offset(0, 2),
										),
									],
								),
								child: Row(
									children: [
										for (var index = 0; index < items.length; index++)
											Expanded(
												child: Padding(
													padding: const EdgeInsets.symmetric(horizontal: 2),
													child: _BottomMenuButton(
														item: items[index],
														isSelected: index == selectedIndex,
														onTap: () => onSelected(index),
													),
												),
											),
									],
								),
							),
						),
					),
				),
			),
		);
	}
}

class _BottomMenuButton extends StatelessWidget {
	const _BottomMenuButton({
		required this.item,
		required this.isSelected,
		required this.onTap,
	});

	final BottomMenuItem item;
	final bool isSelected;
	final VoidCallback onTap;

	@override
	Widget build(BuildContext context) {
		return Material(
			color: Colors.transparent,
			child: InkWell(
				borderRadius: BorderRadius.circular(36),
				onTap: onTap,
				child: AnimatedContainer(
					duration: const Duration(milliseconds: 180),
					padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
					decoration: BoxDecoration(
						color: isSelected
								? const Color(0x55444E5A)
								: Colors.transparent,
						border: isSelected
								? Border.all(color: const Color(0x24FFFFFF))
								: null,
						borderRadius: BorderRadius.circular(36),
					),
					child: Column(
						mainAxisSize: MainAxisSize.min,
						children: [
							Icon(
								item.icon,
								color: isSelected
										? const Color(0xFF6CB2FF)
										: const Color(0xFFF5F7FA),
								size: 22,
							),
							const SizedBox(height: 6),
							Text(
								item.label,
								maxLines: 1,
								overflow: TextOverflow.ellipsis,
								style: Theme.of(context).textTheme.labelLarge?.copyWith(
											color: isSelected
													? const Color(0xFF6CB2FF)
													: const Color(0xFFF5F7FA),
											fontWeight: FontWeight.w700,
										),
							),
						],
					),
				),
			),
		);
	}
}
