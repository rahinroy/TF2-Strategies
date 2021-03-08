import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:convert';
import "dart:collection";

const KEY_TO_USD =
    "https://dispenser.tf/bulk/api_market_transaction_history/?appid=440&market_name=MANN CO. SUPPLY CRATE KEY&contextid=2&currency_key=BITCOIN";

const REF_TO_KEY =
    "https://dispenser.tf/bulk/api_market_transaction_history/?appid=440&market_name=REFINED%20METAL&contextid=2&currency_key=KEY_CREDIT";

const MIN_VOL = 10;

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
  List<dynamic> history = json.decode(dom.body.text)["transactions"];
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
List<List<double>> formatKeyToUSD(keyList) {
  List<List<double>> convertedKeyList = [];
  SplayTreeMap<double, List<double>> sortedDates =
      new SplayTreeMap<double, List<double>>();

  // print(keyList[0]["volume"]);
  for (int x = keyList.length - 1; x > -1; x--) {
    //min volume
    if (keyList[x]["volume"] >= MIN_VOL) {
      sortedDates[keyList[x]["created"].toDouble()] = [
        double.parse(keyList[x]["price"]),
        keyList[x]["volume"]
      ];
    }
  }

  for (final double time in sortedDates.keys) {
    convertedKeyList.add([
      sortedDates[time][0], //price
      sortedDates[time][1], //vol
      time, //time
    ]);
  }
  return convertedKeyList;
}

List<List<double>> formatKeyToRef(refList) {
  List<List<double>> convertedRefList = [];
  SplayTreeMap<double, List<double>> sortedDates =
      new SplayTreeMap<double, List<double>>();

  // print(keyList[0]["volume"]);
  for (int x = refList.length - 1; x > -1; x--) {
    //min volume
    if (refList[x]["volume"] >= MIN_VOL) {
      sortedDates[refList[x]["created"].toDouble()] = [
        double.parse(refList[x]["price"]),
        refList[x]["volume"]
      ];
    }
  }

  for (final double time in sortedDates.keys) {
    convertedRefList.add([
      1 / sortedDates[time][0], //price
      time, //time
    ]);
  }
  return convertedRefList;
}

void writeToCSV(info, filename) async {
  String csv = const ListToCsvConverter().convert(info);
  File file = await File("${filename}.csv");
  file.writeAsString(csv);
}

void keyToUSD() async {
  await writeToCSV(
      formatKeyToUSD(getHistoryToJSON(await construct(KEY_TO_USD))),
      "data_dispenser_keyToUSD");
}

void keyToRef() async {
  await writeToCSV(
      formatKeyToRef(getHistoryToJSON(await construct(REF_TO_KEY))),
      "data_dispenser_keyToRef");
}

void wrapper() async {
  keyToRef();
  // keyToUSD();
}

void main() async {
  wrapper();
}
