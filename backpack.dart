import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:convert';

const KEY_LINK =
    "https://backpack.tf/api/IGetPriceHistory/v1?item=Mann%20Co.%20Supply%20Crate%20Key&quality=Unique&tradable=Tradable&craftable=Craftable&priceindex=0&key=603f03a9b5de2a65ec2c5dcb";

const REF_LINK =
    "https://backpack.tf/api/IGetPriceHistory/v1?item=Refined%20Metal&quality=Unique&tradable=Tradable&craftable=Craftable&priceindex=0&key=603f03a9b5de2a65ec2c5dcb";

/**
 * basic function for a GET request
 * returns dom of the page
*/
Future<dom.Document> construct(link) async {
  http.Response response = await http.get(link);
  dom.Document doc = parser.parse(response.body);
  await sleep(const Duration(seconds: 1));
  return doc;
}

/**
 * returns a list where each index is 1 datapoint for a given item containing a map with keys:
 *    value: value at time of datapoint
 *    value_high: highest value between this period and the last timestamp i think?
 *    currency: currency of value
 *    timestamp: standard unix epoch time
*/
List<dynamic> getHistoryToJSON(dom) {
  List<dynamic> history = json.decode(dom.body.text)["response"]["history"];
  return history;
}

/**
 * returns a list where:
 * Each outer index is a datapoint of the price of item
 * Each inner index is contains information about the datapoint
 * inner index values:
 *    0: value: value of item in USD
 *    1: value_high: highest value between timestamps in USD
 *    2: timestamp: standard unix epoch time
 */
List<List<double>> convertKeyToUSD(keyList, refList) {
  List<List<double>> convertedKeyList = [];

  //timestamps are different for both lists, so we have to accelerate refList seperately
  int refIndex = 0;
  for (int i = 0; i < keyList.length; i++) {
    while ((refIndex + 1) < refList.length &&
        refList[refIndex + 1]["timestamp"] <= keyList[i]["timestamp"]) {
      refIndex++;
    }
    double refToUSD = refList[refIndex]["value"];
    List<double> datapoint = [
      keyList[i]["value"] * refToUSD,
      keyList[i]["value_high"] * refToUSD,
      keyList[i]["timestamp"].toDouble()
    ];
    convertedKeyList.add(datapoint);
  }
  return convertedKeyList;
}

void writeToCSV(keyInformation, filename) async {
  String csv = const ListToCsvConverter().convert(keyInformation);
  File file = await File(filename + ".csv");
  file.writeAsString(csv);
}

List<List<double>> formatSingleCall(keyList) {
  List<List<double>> formattedKeyList = [];
  for (dynamic keyInfo in keyList) {
    List<double> datapoint = [
      (keyInfo["value"].toDouble() + keyInfo["value_high"]) / 2,
      keyInfo["timestamp"].toDouble()
    ];
    formattedKeyList.add(datapoint);
  }
  return formattedKeyList;
}

void keyToUSD() async {
  List<dynamic> keyHistory = getHistoryToJSON(await construct(KEY_LINK));
  List<dynamic> refHistory = getHistoryToJSON(await construct(REF_LINK));
  await writeToCSV(
      convertKeyToUSD(keyHistory, refHistory), "data_backpack_keyToUSD");
}

void keyToRef() async {
  List<dynamic> keyHistory = getHistoryToJSON(await construct(KEY_LINK));
  writeToCSV(formatSingleCall(keyHistory), "data_backpack_keyToRef");
}

void wrapper() async {
  // keyToUSD();
  keyToRef();
}

void main() async {
  wrapper();
}
