/*
Get data from Xidian Sport.
Copyright 2022 SuperBart

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Please refer to ADDITIONAL TERMS APPLIED TO WATERMETER SOURCE CODE
if you want to use.
*/

import 'dart:convert';

import 'package:crypto/crypto.dart';
/* This file is a mess with orders! I need to some sort of cache support. */

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:encrypt/encrypt.dart';
import 'package:watermeter/repository/general.dart';
import 'package:watermeter/model/xidian_sport/punch.dart';
import 'package:watermeter/model/xidian_sport/score.dart';
import 'package:watermeter/model/user.dart';

/// Get base64 encoded data. Which is rsa encrypted [toEnc] using [pubKey].
String rsaEncrypt(String toEnc, String pubKey) {
  dynamic publicKey = RSAKeyParser().parse(pubKey);
  return Encrypter(RSA(publicKey: publicKey)).encrypt(toEnc).base64;
}

class SportSession {
  var username = "";

  var userId = '';

  final _baseURL = 'http://xd.5itsn.com/app/';

  final rsaKey = """-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAq4l
aolA7zAk7jzsqDb3Oa5pS/uCPlZfASK8Soh/NzEmry77QDZ
2koyr96M5Wx+A9cxwewQMHzi8RoOfb3UcQO4UDQlMUImLuz
Unfbk3TTppijSLH+PU88XQxcgYm2JTa546c7JdZSI6dBeXO
JH20quuxWyzgLk9jAlt3ytYygPQ7C6o6ZSmjcMgE3xgLaHG
vixEVpOjL/pdVLzXhrMqWVAnB/snMjpCqesDVTDe5c6OOmj
2q5J8n+tzIXtnvrkxQSDaUp8DWF8meMwyTErmYklMXzKic2
rjdYZpHh4x98Fg0Q28sp6i2ZoWiGrJDKW29mntVQQiDNhKD
awb4B45zUwIDAQAB
-----END PUBLIC KEY-----""";

  final _commonHeader = {
    'channel': 'H5',
    'version': '99999',
    'type': '0',
  };

  static final _commonSignParams = {
    'appId': '3685bc028aaf4e64ad6b5d2349d24ba8',
    'appSecret': 'e8167ef026cbc5e456ab837d9d6d9254'
  };

  String _getSign(Map<String, dynamic> params) {
    var toCalculate = '';
    // Map in dart is not sorted by keys:-O
    for (var i in params.keys.toList()..sort()) {
      toCalculate += "&$i=${params[i]}";
    }
    // sure it is hexString.
    return md5.convert(utf8.encode(toCalculate.substring(1))).toString();
  }

  Map<String, dynamic> _getHead(Map<String, dynamic> payload) {
    Map<String, dynamic> toReturn = _commonHeader;
    toReturn["timestamp"] = DateTime.now().millisecondsSinceEpoch.toString();
    Map<String, dynamic> forSign = payload;
    forSign["timestamp"] = toReturn["timestamp"];
    toReturn['sign'] = _getSign(forSign);
    return toReturn;
  }

  /// Maybe I wrote how to store the data is better.
  Dio get _dio {
    Dio toReturn = Dio(BaseOptions(
      baseUrl: _baseURL,
      contentType: Headers.formUrlEncodedContentType,
    ));
    toReturn.interceptors.add(CookieManager(SportCookieJar));
    return toReturn;
  }

  Future<Map<String, dynamic>> require({
    required String subWebsite,
    required Map<String, dynamic> body,
    bool isForce = false,
  }) async {
    body.addAll(_commonSignParams);
    var response = await _dio.post(subWebsite,
        data: body,
        options: Options(
          headers: _getHead(body),
        ));
    return response.data;
  }

  Future<void> login({
    required String? username,
    required String? password,
    void Function(int, String)? onResponse,
  }) async {
    if (username == null || password == null) {
      throw "???????????????????????????????????????";
    }
    print("userId: $userId");
    if (userId != "") {
      if (onResponse != null) {
        onResponse(100, "????????????");
      }
    }
    this.username = username;
    var response = await require(
      subWebsite: "/h5/login",
      body: {
        "uname": username,
        "pwd": rsaEncrypt(password, rsaKey),
        "openid": ""
      },
    );
    if (response["returnCode"] != "200" && response["returnCode"] != 200) {
      throw "???????????????${response["returnMsg"]}";
    } else {
      userId = response["data"]["id"].toString();
      _commonHeader["token"] = response["data"]["token"];
      if (onResponse != null) {
        onResponse(100, "????????????");
      }
    }
  }

  Future<String> getTermID() async {
    var response =
        await require(subWebsite: "/stuTermPunchRecord/findList", body: {
      'userId': userId,
    });
    if (response["returnCode"] == "200") {
      return response["data"][0]["sysTermId"].toString();
    } else {
      throw "???????????????????????????${response["returnMsg"]}";
    }
  }

  /// Dynamic data.
  Future<PunchDataList> getPunchData(bool isValid) async {
    PunchDataList toReturn = PunchDataList();
    if (userId == "") {
      await login(
          username: user["idsAccount"], password: user["sportPassword"]);
    }
    var response = await require(
      subWebsite: "stuPunchRecord/findPager",
      body: {
        'userNum': username,
        'sysTermId': await getTermID(),
        'pageSize': "999",
        'pageIndex': "1"
      },
    );
    for (var i in response["data"]) {
      toReturn.allTime++;
      if (i["state"].toString().contains("???????????????????????????")) {
        toReturn.valid++;
      }
      if (isValid && !i["state"].toString().contains("???????????????????????????")) {
        continue;
      }
      toReturn.all.add(PunchData(i["machineName"], i["weekNum"], i["punchDay"],
          i["punchTime"], i["state"]));
    }
    return toReturn;
  }

  /// "Static" Data.
  Future<void> getSportScore() async {
    SportScore toReturn = SportScore();
    if (userId == "") {
      await login(
          username: user["idsAccount"], password: user["sportPassword"]);
    }
    var response = await require(
      subWebsite: "measure/getStuTotalScore",
      body: {"userId": userId},
    );
    for (var i in response["data"]) {
      if (i.keys.contains("graduationStatus")) {
        toReturn.total = i["totalScore"];
        toReturn.detail = i["gradeType"];
      } else {
        SportScoreOfYear toAdd = SportScoreOfYear(
            year: i["year"],
            totalScore: i["totalScore"],
            rank: i["rank"],
            gradeType: i["gradeType"]);
        var anotherResponse = await require(
          subWebsite: "measure/getStuScoreDetail",
          body: {"meaScoreId": i["meaScoreId"]},
        );
        for (var i in anotherResponse["data"]) {
          toAdd.details.add(SportItems(
              examName: i["examName"],
              examunit: i["examunit"],
              actualScore: i["actualScore"] ?? "0",
              score: i["score"] ?? 0.0,
              rank: i["rank"] ?? "?????????"));
        }
        toReturn.list.add(toAdd);
      }
    }
    sportScore = toReturn;
  }
}

var toUse = SportSession();

Future<PunchDataList> getPunchData(bool isValid) => toUse.getPunchData(isValid);

Future<SportScore> getSportScore() async {
  if (sportScore.detail == "") {
    await toUse.getSportScore();
  }
  return Future.delayed(const Duration(microseconds: 10), () => sportScore);
}

Future<void> sportLogin(void Function(int, String)? whatever) => toUse.login(
    username: user["idsAccount"],
    password: user["sportPassword"],
    onResponse: whatever);
