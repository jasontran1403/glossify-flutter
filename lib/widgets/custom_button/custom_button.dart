import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/text_style/text_style.dart';


class PrimaryButton extends StatelessWidget {
  final String? buttonText;
  final Function? callBack;
  final Color? bgColor;
  final Color? borderColor;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? fontColor;
  final bool? showLoader;
  final BorderRadiusGeometry? borderRadius;
  final double? height;
  final double? width;
  final String? preIcon;
  final double? preIconSize;
  final Color? preIconColor;

  const PrimaryButton({
    super.key,
    this.buttonText,
    this.callBack,
    this.bgColor,
    this.fontSize,
    this.fontWeight,
    this.showLoader,
    this.fontColor,
    this.borderColor,
    this.borderRadius,
    this.height,
    this.width,
    this.preIcon,
    this.preIconSize,
    this.preIconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height ?? 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bgColor ?? AppColors.primaryColor,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: InkWell(
        onTap: callBack as void Function()?,
        child: Container(
          height: 50,
          width: double.infinity,
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (preIcon != null) ...[
                SvgPicture.asset(
                  preIcon!,
                  height: preIconSize ?? 20,
                  color: preIconColor ?? AppColors.whiteColor,
                ),
                SizedBox(width: 8.0),
              ],
              showLoader ?? false
                  ? const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.whiteColor,
                    ),
                  ),
                ),
              )
                  : Text(
                buttonText!,
                textAlign: TextAlign.center,
                style: CommonStyle.appTextStyle(
                  color: fontColor ?? AppColors.whiteColor,
                  fontSize: fontSize ?? 18,
                  fontWeight: fontWeight ?? FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
