import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hair_sallon/utils/app_colors/app_colors.dart';
import 'package:hair_sallon/utils/text_style/text_style.dart';

class AppTextFormField extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? titleName;
  final TextInputAction? textInputAction;
  final TextInputType? textInputType;
  final bool? obscureText;
  final bool? isTextShow;
  final Function? callBackTextFormField;
  final Function? callBackOnChange;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final Color? fillColor;
  final BoxConstraints? suffixConstraints;
  final bool? readOnly;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final bool? enabled;
  final bool? isTitleName;
  final int? maxLines;
  final BorderRadius? disabledBorderRadius;
  final BorderRadius? focusedBorderRadius;
  final BorderRadius? enabledBorderRadius;
  final EdgeInsetsGeometry? contentPadding;
  final double? height;
  final Color? textColor;
  final TextAlign? textAlign;
  final FocusNode? focusNode;

  const AppTextFormField({
    super.key,
    this.controller,
    this.hintText,
    this.textInputAction,
    this.textInputType,
    this.obscureText,
    this.suffixIcon,
    this.prefixIcon,
    this.readOnly,
    this.callBackOnChange,
    this.callBackTextFormField,
    this.fillColor,
    this.maxLength,
    this.suffixConstraints,
    this.inputFormatters,
    this.enabled,
    this.titleName,
    this.isTitleName,
    this.maxLines,
    this.disabledBorderRadius,
    this.focusedBorderRadius,
    this.enabledBorderRadius,
    this.isTextShow,
    this.contentPadding,
    this.height,
    this.textColor,
    this.textAlign,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        isTextShow == true
            ? Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            titleName ?? "",
            style: CommonStyle.appTextStyle(
              fontSize: 14,
              color: AppColors.blackColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        )
            : SizedBox.shrink(),
        SizedBox(
          height: height ?? 48,
          child: TextFormField(
            maxLines: maxLines,
            textAlign: textAlign ?? TextAlign.start,
            controller: controller,
            enabled: enabled ?? true,
            readOnly: readOnly ?? false,
            textInputAction: textInputAction ?? TextInputAction.next,
            keyboardType: textInputType ?? TextInputType.text,
            cursorColor: AppColors.blackColor,
            obscuringCharacter: "*",
            maxLength: maxLength,
            obscureText: obscureText ?? false,
            focusNode: focusNode,
            inputFormatters: inputFormatters ?? [],
            onChanged: (value) {
              if (callBackOnChange != null) callBackOnChange!(value);
            },
            style: CommonStyle.appTextStyle(
              color: textColor ?? AppColors.blackColor,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              prefixIcon: prefixIcon,
              counterText: "",
              contentPadding: contentPadding ??
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              hintText: hintText ?? "HintText",
              filled: true,
              fillColor: fillColor ?? AppColors.whiteColor,
              hintStyle: CommonStyle.appTextStyle(
                color: AppColors.mistBlueColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: disabledBorderRadius ?? BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.porcelainColor,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: focusedBorderRadius ?? BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.porcelainColor,
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: enabledBorderRadius ?? BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: AppColors.porcelainColor,
                  width: 1,
                ),
              ),
              suffixIcon: suffixIcon,
              suffixIconConstraints: suffixConstraints,
            ),
            onTap: () {
              if (callBackTextFormField != null) callBackTextFormField!();
            },
          ),
        ),
      ],
    );
  }
}
