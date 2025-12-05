import 'package:flutter/material.dart';

const SizedBox kCommonSpaceV15 = SizedBox(height: 15);
const SizedBox kCommonSpaceV20 = SizedBox(height: 20);
const SizedBox kCommonSpaceV30 = SizedBox(height: 30);
const SizedBox kCommonSpaceV50 = SizedBox(height: 50);
const SizedBox kCommonSpaceV100 = SizedBox(height: 100);
const SizedBox kCommonSpaceV400 = SizedBox(height: 400);
const SizedBox kCommonSpaceH15 = SizedBox(width: 15);
const SizedBox kCommonSpaceH20 = SizedBox(width: 20);
const SizedBox kCommonSpaceH30 = SizedBox(width: 30);
const SizedBox kCommonSpaceV5 = SizedBox(height: 5);
const SizedBox kCommonSpaceV3 = SizedBox(height: 3);
const SizedBox kCommonSpaceH5 = SizedBox(width: 5);
const SizedBox kCommonSpaceV10 = SizedBox(height: 10);
const SizedBox kCommonSpaceH10 = SizedBox(width: 10);
const SizedBox kCommonSpaceH2 = SizedBox(width: 2);
const SizedBox kCommonSpaceH3 = SizedBox(width: 3);
const EdgeInsets kCommonScreenPadding = EdgeInsets.only(top: 50,bottom: 30,left: 15,right: 15);
const EdgeInsets kCommonScreenPaddingH = EdgeInsets.symmetric(horizontal: 24);
const EdgeInsets kCommonScreenPaddingV = EdgeInsets.symmetric(vertical: 15);
const EdgeInsets kCommonScreenPadding10 = EdgeInsets.all(10);
const EdgeInsets kCommonScreenPadding5 = EdgeInsets.all(5);

double kDeviceWidth(BuildContext context) {
  return MediaQuery.of(context).size.width;
}

double kDeviceHeight(BuildContext context) {
  return MediaQuery.of(context).size.height;
}
