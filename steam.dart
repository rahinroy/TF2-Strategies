import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:html/dom.dart' as dom;
import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:convert';

const KEY_LINK =
    "https://steamcommunity.com/market/pricehistory/?country=US&currency=1&appid=730&market_hash_name=";

const CASE_WEP = [
  //broken fang
  "CZ75-Auto | Vendetta",
  "P90 | Cocoa Rampage",
  "G3SG1 | Digital Mesh",
  "Galil AR | Vandal",
  "P250 | Contaminant",
  "M249 | Deep Relief",
  "MP5-SD | Condition Zero",
  //fracture
  "Negev | Ultralight",
  "P2000 | Gnarled",
  "SG 553 | Ol' Rusty",
  "SSG 08 | Mainframe 001",
  "P250 | Cassette",
  "P90 | Freight",
  "PP-Bizon | Runic",
  //prisma 2
  "AUG | Tom Cat",
  "AWP | Capillary",
  "CZ75-Auto | Distressed",
  "Desert Eagle | Blue Ply",
  "MP5-SD | Desert Strike",
  "Negev | Prototype",
  "R8 Revolver | Bone Forged",
  //cs20
  "Dual Berettas | Elite 1.6",
  "Tec-9 | Flash Out",
  "MAC-10 | Classic Crate",
  "MAG-7 | Popdog",
  "SCAR-20 | Assault",
  "FAMAS | Decommissioned",
  "Glock-18 | Sacrifice",
  //shattered web
  "MP5-SD | Acid Wash",
  "Nova | Plume",
  "G3SG1 | Black Sand",
  "R8 Revolver | Memento",
  "Dual Berettas | Balance",
  "SCAR-20 | Torn",
  "M249 | Warbird"
];

const WEP_QUALITY = [
  "Factory New",
  "Minimal Wear",
  "Field-Tested",
  "Well-Worn",
  "Battle-Scarred"
];

const COOKIE = {'Cookie': 'steamLoginSecure=GetYourCookie'};

/**
 * basic function for a GET request
 * returns dom of the page
*/
Future<dom.Document> construct(link) async {
  http.Response response = await http.get(link, headers: COOKIE);
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
  List<dynamic> history = json.decode(dom.body.text)["prices"];
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
List<List<double>> format(keyList) {
  const EXTRA_CHARS_IN_DATE = 4;
  const MONTHS = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec"
  ];

  //remove extra chars in date info
  for (int x = 0; x < keyList.length; x++) {
    keyList[x][0] =
        keyList[x][0].substring(0, keyList[x][0].length - EXTRA_CHARS_IN_DATE);
  }

  //Mar 07 2014 01
  //convert to epoch time
  for (int x = 0; x < keyList.length; x++) {
    List<dynamic> dateInfo = keyList[x][0].split(" ");
    int month = MONTHS.indexOf(dateInfo[0]) + 1;
    int day = int.parse(dateInfo[1]);
    int year = int.parse(dateInfo[2]);
    int hour = int.parse(dateInfo[3]);
    keyList[x][0] =
        DateTime.utc(year, month, day, hour).millisecondsSinceEpoch / 1000;
  }

  List<List<double>> convertedKeyList = [];
  for (int x = 0; x < keyList.length; x++) {
    convertedKeyList.add([
      keyList[x][1].toDouble(), //price
      // keyList[x][2], //volume
      keyList[x][0].toDouble(), //time
    ]);
  }
  return convertedKeyList;
}

void writeToCSV(keyInformation, cnt) async {
  String csv = const ListToCsvConverter().convert(keyInformation);
  File file = await File("crate_data/${cnt}.csv");
  file.writeAsString(csv);
}

void wrapper() async {
  int count = 0;
  for (int x = 0; x < CASE_WEP.length; x++) {
    String i = CASE_WEP[x].replaceAll(" ", "%20").replaceAll("|", "%7C");
    for (int y = 0; y < WEP_QUALITY.length; y++) {
      String j = "%20%28" + WEP_QUALITY[y].replaceAll(" ", "%20") + "%29";
      try {
        await writeToCSV(
            format(getHistoryToJSON(await construct(KEY_LINK + i + j))), count);
        count++;
        print(count.toString() +
            " / " +
            (count.toDouble() / (CASE_WEP.length * WEP_QUALITY.length))
                .toString());
      } catch (e) {
        print(KEY_LINK + i + j);
      }
    }
  }
}

void main() async {
  wrapper();
}
