import 'package:flutter/material.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/text_style/text_style.dart';

class ComAppbar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool? centerTitle;
  final bool? isTitleBold;
  final bool isShowShadow;
  final Color? bgColor;
  final bool? automaticallyImplyLeading;
  final IconThemeData? iconTheme;
  final double? elevation;
  final PreferredSizeWidget? bottom;

  const ComAppbar({
    super.key,
    this.title,
    this.leading,
    this.actions,
    this.centerTitle,
    this.isTitleBold = false,
    this.isShowShadow = false,
    this.bgColor,
    this.elevation,
    this.automaticallyImplyLeading,
    this.iconTheme,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      scrolledUnderElevation: 0,
      backgroundColor: bgColor ?? Theme.of(context).appBarTheme.backgroundColor,
      elevation: elevation,
      iconTheme: iconTheme,
      leading: leading,
      centerTitle: centerTitle ?? true,
      automaticallyImplyLeading: automaticallyImplyLeading ?? true,
      title: Text(
        title ?? '',
        style: CommonStyle.appTextStyle(
          fontSize: 18,
          fontWeight: isTitleBold == true ? FontWeight.w700 : FontWeight.normal,
          color: AppColors.blackColor,
        ),
      ),
      actions: actions,
      bottom: bottom,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    bottom == null
        ? kToolbarHeight
        : kToolbarHeight + bottom!.preferredSize.height,
  );
}
