///
/// Copyright (C) 2021 盈宝信息科技（广州）有限公司 All Rights Reserved.
///

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:openapi/quotes/model/quote_price_more.dart';
import 'package:openapi/quotes/model/stock_index_quote_detail.dart';
import 'package:openapi/trade/model/order_create_dto.dart';
import 'package:win_bull_app/header.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:win_bull_app/language/app_string.dart';
import 'package:win_bull_app/model/quotes/market_model.dart';
import 'package:win_bull_app/model/quotes/market_type.dart';
import 'package:win_bull_app/model/trade/home/base_data_model/trade_condition_order_model.dart';
import 'package:win_bull_app/model/trade/home/base_data_model/trade_hold_model.dart';
import 'package:win_bull_app/page/quotes/quotes_home.dart';
import 'package:win_bull_app/page/root.dart';
import 'package:win_bull_app/page/trade/trade_home.dart';
import 'package:win_bull_app/model/trade/stock_search_item_model.dart';

import 'package:win_bull_app/network/Api.dart';
import 'package:win_bull_app/model/quotes/stock_model/stock_model.dart';
import 'package:win_bull_app/ui/trade/deal/trade_order_type_desc.dart';
import 'package:win_bull_app/ui/trade/deal_item/deal_term_row.dart';

import 'package:win_bull_app/util/toast.dart';
import 'package:win_bull_app/util/search_tool.dart';
import 'package:win_bull_app/ui/trade/dialog/trade_action_sheet.dart';
import 'package:win_bull_app/util/trade/condition_order/condition_order_types.dart';
import 'package:win_bull_app/util/trade/trade_min_change_price.dart';
import 'package:win_bull_app/view_model/trade/stock_deal_form_vm.dart';

/// 交易频道工具
class TradeTools {
  // 根据市场类型获取货币
  static String getCurrencyByMarket(String market) {
    switch (market) {
      case 'HK':
        return 'HKD';
      case 'US':
        return 'USD';
      default:
        return '';
    }
  }

  // 所有订单类型【暂只做记录】
  // 1 市价单 2 增强限价单 3 限价单 11 止损市价单 12 止损限价单 21 竞价市价单 22 竞价限价单 32 特别限价单
  static List<Map<String, dynamic>> get allOrderTypes => [
        {
          'label': curAppString.orderType3, // 限价单
          'value': 3,
        },
        {
          'label': curAppString.orderType3, // 限价单(增强)
          'value': 2,
        },
        {
          'label': curAppString.orderType1, // 市价单
          'value': 1,
        },
        {
          'label': curAppString.orderType12, // 止损限价单
          'value': 12,
        },
        {
          'label': curAppString.orderType11, // 止损市价单
          'value': 11,
        },
        {
          'label': curAppString.orderType22, // 竞价限价单
          'value': 22,
        },
        {
          'label': curAppString.orderType21, // 竞价市价单
          'value': 21,
        },
        {
          'label': curAppString.orderType32, // 特别限价单
          'value': 32,
        },
      ];

  /// 订单类型(港股)
  /// 2增强限价单 1市价单 21竞价市价单[竞价单] 22竞价限价单
  /// [tradeStatus] 交易所状态。0:无交易,10,盘前竞价,20:等待开盘,30:交易中,40:午休,50:盘后竞价,60:已收盘,70:停牌
  static List<Map<String, dynamic>> hkOrderTypeOptions({
    int? tradeStatus,
    OrderCreateDTOProductTypeEnum? productType,
    int? action,
    StockModel? stockModel,
  }) {
    if (productType == OrderCreateDTOProductTypeEnum.n2) {
      return warrantOrderTypeOptions;
    }
    List<Map<String, dynamic>> resMaps = [];
    List<Map<String, dynamic>> tradeMaps = [
      {
        'label': curAppString.orderType3, // 限价单(增强)
        'value': 2,
        'width': 75.0.sw,
        'desc': orderTypeDesc2(),
      },
      {
        'label': curAppString.orderType1, // 市价单
        'value': 1,
        'width': 75.0.sw,
        'desc': orderTypeDesc1(),
      },
    ];
    List<Map<String, dynamic>> bidMaps = [
      {
        'label': curAppString.orderType22, // 竞价限价单
        'value': 22,
        'width': 110.0.sw,
        'desc': orderTypeDesc22(),
      },
      {
        'label': curAppString.orderType21, // 竞价市价单
        'value': 21,
        'width': 110.0.sw,
        'desc': orderTypeDesc21(),
      },
    ];
    if (isTradeTimes('HK', tradeStatus: tradeStatus)) {
      // 交易时段
      resMaps.addAll(tradeMaps);
      resMaps.addAll(bidMaps);
    } else {
      // 竞价时段
      resMaps.addAll(bidMaps);
      resMaps.addAll(tradeMaps);
    }
    resMaps.addAll(ConditionOrderTypes.getOrderTypesByParams(
      marketType: 'HK',
      action: action,
      stockModel: stockModel,
    ));
    return resMaps;
  }

  static List<Map<String, dynamic>> usOrderTypeOptions({
    int? action,
    StockModel? stockModel,
  }) {
    List<Map<String, dynamic>> options = usOrderTypes;
    options.addAll(ConditionOrderTypes.getOrderTypesByParams(
      marketType: 'US',
      action: action,
      stockModel: stockModel,
    ));
    return options;
  }


  /// 当前交易所状态
  ///
  /// [marketType] 交易所类型
  /// [currentStatus] 指定当前交易所状态默认值
  static int? marketStatus(String marketType, [int? currentStatus]) {
    int? tradeStatus;
    try {
      // 优先获取推送市场状态
      tradeStatus = Get.find<RootLogic>().marketStatus[marketType]?.status;
      tradeStatus ??= currentStatus;
      if (tradeStatus == null) {
        // 从热门行情获取兜底市场状态
        MarketModel marketModel = Get.find<QuotesHomeLogic>()
            .markets
            .firstWhere((e) => e.id == marketType);
        StockModel stockModel = marketModel.curCategory.first.hots.first;
        tradeStatus = stockModel.tradeStatus.value;
        Log.d("current tradeStatus was : $tradeStatus from QuotesHomeLogic");
      } else {
        Log.d("current tradeStatus was : $tradeStatus from RootLogic");
      }
    } catch (e) {
      Log.e(e);
    }
    return tradeStatus;
  }

  /// 是否为可持续交易阶段
  ///
  /// [tradeStatus] 指定当前交易所状态默认值
  static bool isTradeTimes(String marketType, {int? tradeStatus}) {
    return ![10, 20, 50].contains(marketStatus(marketType, tradeStatus));
  }

  /// 是否为盘前
  static bool isPreTradeTimes(String marketType, {int? tradeStatus}) {
    return [10].contains(marketStatus(marketType, tradeStatus));
  }

  /// 是否为盘后
  static bool isAfterTradeTimes(String marketType, {int? tradeStatus}) {
    return [50].contains(marketStatus(marketType, tradeStatus));
  }

  // 订单类型(涡轮牛熊)
  // 1市价单 2增强限价单 3限价单
  static List<Map<String, dynamic>> get warrantOrderTypeOptions => [
        {
          'label': curAppString.orderType3, // 限价单(增强)
          'value': 2,
          'width': 75.0.sw,
          'desc': orderTypeDesc2(),
        },
        {
          'label': curAppString.orderType1, // 市价单
          'value': 1,
          'width': 75.0.sw,
          'desc': orderTypeDesc1US(),
        },
      ];

  // 订单类型(美股)
  // 1市价单 3限价单
  static List<Map<String, dynamic>> get usOrderTypes => [
        {
          'label': curAppString.orderType3, // 限价单
          'value': 3,
          'width': 75.0.sw,
          'desc': orderTypeDesc3US(),
        },
        {
          'label': curAppString.orderType1, // 市价单
          'value': 1,
          'width': 75.0.sw,
          'desc': orderTypeDesc1US(),
        },
      ];

  /// 订单类型选项
  ///
  /// [productType] 产品类型 1_NORMAL_普通订单，2_WARRANT_涡轮牛熊，3_ETF
  /// [tradeStatus] 交易所状态。0:无交易,10,盘前竞价,20:等待开盘,30:交易中,40:午休,50:盘后竞价,60:已收盘,70:停牌
  static List<Map<String, dynamic>> orderTypeOptions(
    String marketType, {
    OrderCreateDTOProductTypeEnum? productType,
    int? tradeStatus,
    int? action,
    StockModel? stockModel,
  }) {
    if (marketType == 'US') {
      return usOrderTypeOptions(
        action: action,
        stockModel: stockModel,
      );
    }
    return hkOrderTypeOptions(
      tradeStatus: tradeStatus,
      productType: productType,
      action: action,
      stockModel: stockModel,
    );
  }

  /// 获取默认订单交易类型
  static int getTradeTypeByTime(String marketType, {int? tradeStatus}) {
    if (marketType == 'US') {
      // 美股交易默认：3限价单
      return 3;
    }
    // 交易时段默认：2增强限价单，竞价时段默认：22竞价限价单
    return isTradeTimes(marketType, tradeStatus: tradeStatus) ? 2 : 22;
  }

  static List<int> orderTypeKeys({
    required String marketType,
    required StockDealFormVM formVM,
    OrderCreateDTOProductTypeEnum? productType,
    int? action,
    StockModel? stockModel,
  }) {
    // orderTypeOptions已经包含了插入条件单处理
    List<Map<String, dynamic>> typeList = TradeTools.orderTypeOptions(
      marketType,
      productType: productType,
      action: action,
      stockModel: stockModel,
    );
    typeList = formVM.orderTypeOptions(typeList);
    return typeList.map((e) => e['value'] as int).toList();
  }

  /// 根据订单类型判断当前是否可下单、修改、撤单
  static bool checkOrderAllowDeal({
    required int orderType, // 订单类型（2增强限价单 3限价单 32特别限价单 21竞价市价单[竞价单] 22竞价限价单）
    required int
        stockTradeState, // 股票状态（0:无交易,10,盘前竞价,20:等待开盘,30:交易中,40:午休,50:盘后竞价,60:已收盘,70:停牌）
    required int dealType, // 交易类型（1：下单，2：修改，3：撤单）
    int? orderTime, // 订单时间（用于部分修改，撤单判断）
  }) {
    bool flag = true;

    DateTime cTime = DateTime.now(); // 当前时间
    int cYear = cTime.year;
    int cMonth = cTime.month;
    int cDay = cTime.day;

    // 增强限价单
    // 限价单
    // 特别限价单
    if (orderType == 2 || orderType == 3 || orderType == 32) {
      if (dealType == 1) {
        // 下单时间：上午09:30-12:00、下午13:00-16:00
        flag = (cTime.isAfter(DateTime(cYear, cMonth, cDay, 9, 29, 59)) &&
                cTime.isBefore(DateTime(cYear, cMonth, cDay, 12, 01, 00))) ||
            (cTime.isAfter(DateTime(cYear, cMonth, cDay, 12, 59, 59)) &&
                cTime.isBefore(DateTime(cYear, cMonth, cDay, 16, 01, 00)));
      }
      if (dealType == 2) {
        // 午间休市时段不允许进行改单
        flag = stockTradeState != 40;
      }
      if (dealType == 3) {
        // 12:00-12:30时间段不允许进行撤单
        flag = cTime.isBefore(DateTime(cYear, cMonth, cDay, 12, 00, 00)) ||
            cTime.isAfter(DateTime(cYear, cMonth, cDay, 12, 30, 00));
      }
    }

    // 竞价市价单
    // 竞价限价单
    if (orderType == 21 || orderType == 22) {
      if (dealType == 1) {
        // 下单时间：早市09:00-09:22、收市16:01-16:10
        flag = (cTime.isAfter(DateTime(cYear, cMonth, cDay, 8, 59, 59)) &&
                cTime.isBefore(DateTime(cYear, cMonth, cDay, 9, 23, 00))) ||
            (cTime.isAfter(DateTime(cYear, cMonth, cDay, 16, 00, 59)) &&
                cTime.isBefore(DateTime(cYear, cMonth, cDay, 16, 11, 00)));
      }
      if (dealType == 2 || dealType == 3) {
        // if (orderTime == null) {
        //   return false;
        // }
        // // 是否是早市竞价
        // bool isAmOrder =
        //     DateTime.fromMillisecondsSinceEpoch(orderTime).hour < 16;
        // if (isAmOrder) {
        //   // 早市竞价，于09:15后不得进行改单、撤单
        //   flag = cTime.isBefore(DateTime(cYear, cMonth, cDay, 9, 15, 00));
        // } else {
        //   // 收市竞价，于16:06之后不可更改或取消
        //   flag = cTime.isBefore(DateTime(cYear, cMonth, cDay, 16, 06, 00));
        // }

        // 早市竞价，于09:15后不得进行改单、撤单
        // 收市竞价，于16:06之后不可更改或取消
        flag = (cTime.isAfter(DateTime(cYear, cMonth, cDay, 8, 59, 59)) &&
                cTime.isBefore(DateTime(cYear, cMonth, cDay, 9, 15, 00))) ||
            (cTime.isAfter(DateTime(cYear, cMonth, cDay, 16, 00, 59)) &&
                cTime.isBefore(DateTime(cYear, cMonth, cDay, 16, 06, 00)));
      }
    }

    return flag;
  }

  /// 获取价格选项类型
  static List<Map<String, dynamic>> getPriceTypes() {
    List<Map<String, dynamic>> priceTypes = [];
    priceTypes.addAll([
      {"value": 1, "label": curAppString.priceTypeSpecify}, // 指定价
      {"value": 2, "label": curAppString.priceTypeFllow}, // 跟市价
      {"value": 3, "label": curAppString.priceTypeBuyOne}, // 跟买一
      {"value": 4, "label": curAppString.priceTypeShellOne}, // 跟卖一
    ]);
    return priceTypes;
  }

  /// 获取显示价格文案
  ///
  /// [specifyPrice] 指定价
  static String getPriceStrWithPriceType({
    required int priceType,
    required String specifyPrice,
  }) {
    String priceStr;
    switch (priceType) {
      case 2: //  跟市价
        priceStr = curAppString.priceTypeFllow;
        break;
      case 3: //  跟买一
        priceStr = curAppString.priceTypeBuyOne;
        break;
      case 4: //  跟卖一
        priceStr = curAppString.priceTypeShellOne;
        break;
      default: // 指定价
        priceStr = specifyPrice;
        break;
    }
    return priceStr;
  }

  /// 可买入卖出数量取整
  /// [count] 预买入卖出总量
  /// [min] 最小一股(手)买入卖出数量
  static int getTradeRoundNum(num count, num min) {
    if (count <= 0 || min <= 0) {
      return 0;
    }
    return (count - (count % min)).floor();
  }

  /// 获取仓位选项类型
  /// [max] 最大可买入卖出
  /// [min] 最小一股(手)买入卖出数量
  static List<Map<String, dynamic>> getPositionTypes({
    int max = 0,
    int min = 0,
  }) {
    List<Map<String, dynamic>> list = [
      {"scale": 1, "label": curAppString.fullQuantity},
      {"scale": 2, "label": "1/2"},
      {"scale": 3, "label": "1/3"},
      {"scale": 4, "label": "1/4"},
    ];
    for (Map<String, dynamic> map in list) {
      // 计算出对应买卖数量
      map["value"] = max > 0 ? getTradeRoundNum(max ~/ map["scale"], min) : 0;
    }
    return list;
  }

  /// 打开选择类型action
  static void showActionSheet({
    required BuildContext context,
    required List<Map<String, dynamic>> actionMapList,
    int? curSelect,
    ValueChanged<int>? callback,
  }) {
    List<String> albelList = [];
    List<int> valueList = [];
    int curIndex = 0;
    for (int i = 0, k = actionMapList.length; i < k; i++) {
      Map<String, dynamic> map = actionMapList[i];
      albelList.add(map['label']);
      valueList.add(map['value']);
      if (map['value'] == curSelect) {
        curIndex = i;
      }
    }
    TradeActionSheet.show(
      context: context,
      curSelect: curIndex,
      actions: albelList,
      callback: (index) => callback?.call(valueList[index]),
    );
  }

  /// 是否为行情会员
  ///
  /// [model] 行情数据
  static bool isQuoteVip(StockModel? model) {
    bool result = false;
    int level = int.tryParse(model?.level ?? "0") ?? 0;
    var market = model?.market ?? "";
    if (market == 'US') {
      result = level >= 1;
    } else if (market == 'HK') {
      result = level >= 2;
    }
    return result;
  }

  // 获取随机uuid v4
  // 110ec58a-a0f2-4ac4-8393-c866d813b8d1 去掉中划线
  static String generateUuid() {
    var uuid = Uuid().v4();
    return uuid.split('-').join('');
  }

  // 字符串生成sha512
  static String generateSha521(String str) {
    if (!strNoEmpty(str)) {
      return '';
    }
    return sha512.convert(utf8.encode(str)).toString();
  }

  // 获取订单类型字符串
  static String getOrderType(String marketType, int? type) {
    if (type == null) return '-';
    List<Map<String, dynamic>> typeList = allOrderTypes;
    typeList.addAll(ConditionOrderTypes.getAllTyps());
    var currentItem = typeList.firstWhere(
          (item) => item['value'] == type,
      orElse: () => {'label': '-'},
    );
    return currentItem['label'];
  }

  // 获取订单状态字符串【弃用】
  static String getOrderState(int state) {
    String stateStr = '';
    // 1 待成交 2 部分成交 3 已成交 4 已撤销 5 已失效 6 下单失败
    switch (state) {
      case 1:
        stateStr = curAppString.orderState1; // 待成交
        break;
      case 2:
        stateStr = curAppString.orderState2; // 部分成交
        break;
      case 3:
        stateStr = curAppString.orderState3; // 已成交
        break;
      case 4:
        stateStr = curAppString.orderState4; // 已撤销
        break;
      case 5:
        stateStr = curAppString.orderState5; // 已失效
        break;
      case 6:
        stateStr = curAppString.orderState6; // 下单失败
        break;
      default:
        stateStr = curAppString.orderState0; // 未知状态
        break;
    }
    return stateStr;
  }

  // 获取当天0点时间戳
  static int getTodayStartTime() {
    // 获取零点时间
    String startTimeStr = dateFormat(DateTime.now(), [yyyy, '/', mm, '/', dd]);
    int startTime = DateTime.parse(startTimeStr).millisecondsSinceEpoch;
    return startTime;
  }

  // 获取当天24点时间戳
  static int getTodayEndTime() {
    // 获取零点时间
    String endTimeStr = dateFormat(DateTime.now(), [yyyy, '/', mm, '/', dd]);
    endTimeStr += ' 23:59:59';
    int endTime = DateTime.parse(endTimeStr).millisecondsSinceEpoch;
    return endTime;
  }

  // 获取最近一段时间的开始时间
  // 1:近一个月 2:近三个月 3.近半年 4.近一年
  static int? getRecentStartTime(int timeType) {
    var now = DateTime.now();
    switch (timeType) {
      case 1:
        return DateTime(now.year, now.month - 1, now.day)
            .millisecondsSinceEpoch;
      case 2:
        return DateTime(now.year, now.month - 3, now.day)
            .millisecondsSinceEpoch;
      case 3:
        return DateTime(now.year, now.month - 6, now.day)
            .millisecondsSinceEpoch;
      case 4:
        return DateTime(now.year - 1, now.month, now.day)
            .millisecondsSinceEpoch;
      default:
        return null;
    }
  }

  // 获取最近6个月的字符串
  static List<String> getLastSixMonthStrs() {
    List<String> months = [];
    DateTime now = DateTime.now();
    for (var i = 0; i < 6; i++) {
      DateTime tmp = DateTime(now.year, now.month - i, now.day);
      months.add(dateFormat(
        tmp,
        [yyyy, curAppString.year, mm, curAppString.month],
      ));
    }
    return months;
  }

  // 获取指定月份的开始及结束时间
  // 1：最近第1个月，2：最近第2个月，3：最近第3个月，4：最近第4个月，5：最近第5个月，6：最近第6个月
  static List<int?> getTheMonthSideTime(int monthType) {
    if (monthType <= 0) return [null, null];
    int index = monthType - 1;
    DateTime now = DateTime.now();
    int startTime = DateTime(
      now.year,
      now.month - index,
      1,
      0,
      0,
      0,
    ).millisecondsSinceEpoch;
    int endTime = DateTime(
      now.year,
      now.month - index + 1,
      1,
      23,
      59,
      59,
    ).add(Duration(hours: -24)).millisecondsSinceEpoch;
    return <int>[startTime, endTime];
  }

  // 只能输入数字的输入框处理
  /// 此方法推荐在controller.addListener回调中使用，
  /// addListener回调会被光标改动触发，TextField的
  /// onChanged方法不会被光标改变触发
  static void numInputTextHandle({
    required TextEditingController controller,
    TextEditingValue? old, // 传了最大值必须要有这个old，否则无法生效，old代表的是改变之前的值
    bool isPrice = false, // 是否是价格格式
    int fixedNum = 2, // 保留小数位数
    int? maxNum, // 这个值代表的是输入的最大位数，不包含小数点后面的，必须要传old
  }) {
    String text = controller.text;
    if (text == "") {
      return;
    }
    if (old != null) {
      RegExp regExp = RegExp(
          r"^(([0-9]\.[0-9]*)|([1-9][0-9]*\.[0-9]*)|([1-9][0-9]*)|[0-9])$");
      if (!regExp.hasMatch(text)) {
        controller.value = old;
        return;
      }
    }

    text = text.splitMapJoin(
      isPrice ? RegExp(r'[0-9.]') : RegExp(r'[0-9]'),
      onMatch: null,
      onNonMatch: (String nonMatch) => '',
    );
    if (maxNum != null) {
      String tmp = text.split('.').first;
      if (tmp.length > maxNum) {
        if (old != null) {
          controller.value = old;
          return;
        }
      }
    }
    if (isPrice) {
      // 当输入为价格格式，进行判断处理，格式小数点两位如【12.88】
      text = getFixedNumStr(numStr: text, fixedLength: fixedNum);
    }
    var selection = controller.value.selection;
    if (selection.baseOffset >= text.length) {
      selection = TextSelection.collapsed(offset: text.length);
    }
    controller.value = TextEditingValue(
      text: text,
      selection: selection,
    );
  }

  /// 数值文本小数点截取
  static String getFixedNumStr({
    String? numStr,
    int? fixedLength,
  }) {
    String text = numStr ?? '';
    int fixedNum = fixedLength ?? 2;
    if (!text.contains('.')) {
      return text;
    }
    if (text.length == 1) {
      // 输入数值错误
      text = '';
    } else if (fixedNum == 0) {
      // 只能输入整数
      text = text.substring(0, text.indexOf('.'));
    } else if (text.split('.').length > 2) {
      // 只能输入一个小数点
      text = text.substring(0, text.length - 1);
    } else if (text.split('.').length == 2) {
      // 限制可输入小数位数
      List<String> strs = text.split('.');
      int subLength = strs[1].length - fixedNum;
      if (subLength > 0) {
        strs[1] = strs[1].substring(0, strs[1].length - subLength);
        text = "${strs[0]}.${strs[1]}";
      }
    }
    return text;
  }

  // 获取交易买卖最小变动价位
  static double getMinChangePrice(StockModel model) {
    String marketType = model.market;
    double price = model.price ?? 0.0;
    bool isEtf = model.isEtf;

    if (marketType == 'US') {
      return 0.010;
    }
    if (isEtf) {
      // etf计算
      return TradeMinChangePrice.getEtfMinChangePrice(price, marketType);
    } else {
      // 涡轮与股票计算规则一致
      return TradeMinChangePrice.getStockMinChangePrice(price, marketType);
    }
  }

  // 买入卖出股票搜索
  static Future<List<StockSearchItemModel>> search({
    String keyword = '', // 关键词
    String marketType = 'HK', // 市场类型
    int searchType = 1, // 搜索类型
  }) async {
    List<StockSearchItemModel> stockList = <StockSearchItemModel>[];
    if (searchType == 1) {
      List<StockSearchItemModel> tmpList = <StockSearchItemModel>[];
      var response = await SearchTool.searchStock(keyword, autoLoading: false);
      if ((response.data?.code ?? '1') == "0") {
        response.data?.data.toList().forEach((item) {
          if (item.marketType == marketType) {
            tmpList.add(StockSearchItemModel.fromProdStock(item));
          }
        });
        stockList = tmpList;
      }
    } else {
      var logic = Get.find<TradeHomeLogic>();
      TradeHoldModel? current;
      if (marketType == 'US') {
        current = logic.usHoldData;
      } else {
        current = logic.hkHoldData;
      }

      if (current.products.isEmpty) {
        stockList = <StockSearchItemModel>[];
      } else {
        List<StockSearchItemModel> tmpList = <StockSearchItemModel>[];
        var holdList = current.products;
        for (var item in holdList) {
          if (item.productName!.contains(keyword) ||
              item.productCode!.contains(keyword)) {
            tmpList.add(StockSearchItemModel.fromHoldItemModel(item));
          }
        }
        stockList = tmpList;
      }
    }
    return stockList;
  }

  // 获取股票交易页按钮颜色，返回red、green
  static String getDealPageColor([int action = 1]) {
    String resColor = '';
    bool isRedMain = SP.getRedGreenSetting() ?? true;

    if (action == 2)
      resColor = isRedMain ? 'green' : 'red';
    else
      resColor = isRedMain ? 'red' : 'green';

    return resColor;
  }

  // 获取股票信息
  static Future<StockModel?> getStockInfo({
    required String wbCode,
    KChartType? type,
    CancelToken? cancelToken,
  }) async {
    try {
      type ??= KChartType.oneDay;
      StockModel model;
      String marketType = wbCode.split(':').first;
      String code = wbCode.split(':').last;
      model = StockModel.withCode(code, marketType);
      var response = await Api().stockIndexDetailV2(
        wbCode,
        type: type,
        cancelToken: cancelToken,
      );
      if (response.data?.code?.toString() != '0') {
        ToastUtils.toast(curAppString.reqError);
        return null;
      }
      StockIndexQuoteDetail? data = response.data?.data;
      if (data == null) {
        ToastUtils.toast(curAppString.handleError);
        return null;
      }
      model.updateWithStockQuoteDetail(data.stockQuoteDetail, type);
      await model.updateKChartData(
        data.stockQuoteDetail.prices?.toList() ?? <QuotePriceMore>[],
        type,
      );
      model.isEtf = data.securityTypeCode == 9 ||
          data.securityTypeCode == 10 ||
          data.securityTypeCode == 16 ||
          data.securityTypeCode == 17 ||
          data.securityTypeCode == 18;
      model.relatedQuotes = data.stockQuoteDetail.relatedQuotes.toList();
      if (data.stockQuoteDetail.warrant != null) {
        if (data.securityTypeCode == 3) {
          model.updateWarrantInfo(data.stockQuoteDetail.warrant);
        } else if (data.securityTypeCode == 11) {
          model.updateBullBearInfo(data.stockQuoteDetail.warrant);
        } else if (data.securityTypeCode == 15) {
          model.updateInlineInfo(data.stockQuoteDetail.warrant);
        }
      }
      return model;
    } catch (e) {
      ToastUtils.toast(curAppString.reqError);
      return null;
    }
  }

  // 判断持仓是否存在传入的股票
  static bool isHoldTheStock({
    required String marketType, // 市场类型
    required String wbCode, // 产品编码
  }) {
    var logic = Get.find<TradeHomeLogic>();
    TradeHoldModel? current;
    if (marketType == 'US') {
      current = logic.usHoldData;
    } else {
      current = logic.hkHoldData;
    }
    if (current.products.isEmpty) {
      return false;
    }
    return current.products.any((item) => item.wbCode == wbCode);
  }

  /// 获取可选订单有效期类型
  ///
  /// [dealType] 订单类型
  /// [productType] 产品类型 1_NORMAL_普通订单，2_WARRANT_涡轮牛熊，3_ETF
  static List<TermType> getTermTypes({
    String? marketType,
    int? dealType,
    OrderCreateDTOProductTypeEnum? productType,
  }) {
    if ([21, 22].contains(dealType)) {
      // 1港股市价单
      return [TermType.today];
    } else if (marketType == 'HK' && [1].contains(dealType)) {
      // 21竞价市价单[竞价单] 22竞价限价单
      return [TermType.today];
    } else if ([
      OrderCreateDTOProductTypeEnum.n2,
      OrderCreateDTOProductTypeEnum.n3,
    ].contains(productType)) {
      // 涡轮牛熊、etf
      return [TermType.today];
    }
    return [TermType.today, TermType.beforeCancel, TermType.customize];
  }

  /// 通过条件单model获取股票现价
  static double getCurPriceByConditionOrderModel(
      TradeConditionOrderModel orderModel) {
    if (orderModel.stockExtInfo == null) return 0.0;
    double showPrice = doubleTools.on(orderModel.stockExtInfo!.newestPrice);

    String marketType = orderModel.exchange;
    if (marketType == MarketType.us.name && orderModel.extendedTrading) {
      if (TradeTools.isPreTradeTimes(marketType) ||
          TradeTools.isAfterTradeTimes(marketType)) {
        // 盘前盘后价格
        showPrice = doubleTools.on(orderModel.stockExtInfo!.preAfterPrice ?? 0);
      }
    }
    return showPrice;
  }

  /// 通过条件单model获取股票涨跌平
  static int getCurPriceStateByConditionOrderModel(
      TradeConditionOrderModel orderModel) {
    if (orderModel.stockExtInfo == null) return 0;
    int state = 0;
    double changeRate =
        doubleTools.on(orderModel.stockExtInfo?.changeRate ?? 0);
    String marketType = orderModel.exchange;
    if (marketType == MarketType.us.name && orderModel.extendedTrading) {
      if (TradeTools.isPreTradeTimes(marketType) ||
          TradeTools.isAfterTradeTimes(marketType)) {
        // 盘前盘后价格
        changeRate =
            doubleTools.on(orderModel.stockExtInfo?.preAfterchangeRate ?? 0);
      }
    }
    if (changeRate > 0) {
      state = 1;
    } else if (changeRate < 0) {
      state = -1;
    } else {
      state = 0;
    }
    return state;
  }

  /// 通过条件单model获取关联股票现价
  static double getRelateCurPriceByConditionOrderModel(
      TradeConditionOrderModel orderModel) {
    if (orderModel.extInfo == null) return 0.0;
    AssetRelatedExtInfo extInfo = orderModel.extInfo as AssetRelatedExtInfo;
    if (extInfo.relatedStockExtInfo == null) return 0.0;
    double showPrice = doubleTools.on(extInfo.relatedStockExtInfo!.newestPrice);

    String marketType = orderModel.exchange;
    if (marketType == MarketType.us.name && orderModel.extendedTrading) {
      if (TradeTools.isPreTradeTimes(marketType) ||
          TradeTools.isAfterTradeTimes(marketType)) {
        // 盘前盘后价格
        showPrice =
            doubleTools.on(extInfo.relatedStockExtInfo!.preAfterPrice ?? 0);
      }
    }
    return showPrice;
  }

  /// 通过条件单model获取关联股票涨跌平
  static int getRelateCurPriceStateByConditionOrderModel(
      TradeConditionOrderModel orderModel) {
    if (orderModel.extInfo == null) return 0;
    AssetRelatedExtInfo extInfo = orderModel.extInfo as AssetRelatedExtInfo;
    if (extInfo.relatedStockExtInfo == null) return 0;
    int state = 0;
    double changeRate =
        doubleTools.on(extInfo.relatedStockExtInfo?.changeRate ?? 0);
    String marketType = orderModel.exchange;
    if (marketType == MarketType.us.name && orderModel.extendedTrading) {
      if (TradeTools.isPreTradeTimes(marketType) ||
          TradeTools.isAfterTradeTimes(marketType)) {
        // 盘前盘后价格
        changeRate = doubleTools
            .on(extInfo.relatedStockExtInfo?.preAfterchangeRate ?? 0);
      }
    }
    if (changeRate > 0) {
      state = 1;
    } else if (changeRate < 0) {
      state = -1;
    } else {
      state = 0;
    }
    return state;
  }

  ///判断是否显示盘前盘后选项
  static bool showUSPreAndAfter(String marketType, int orderType) {
    bool show = false;
    if (marketType == MarketType.us.name) {
      // 美股限价单，条件单支持盘前盘后
      if ([3].contains(orderType) ||
          ConditionOrderTypes.isConditionOrderType(orderType)) {
        show = true;
      }
    }
    return show;
  }
}
