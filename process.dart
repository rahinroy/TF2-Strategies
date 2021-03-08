import 'package:csv/csv.dart';
import 'dart:io';
import 'dart:convert';
import 'package:extended_math/extended_math.dart';
import "dart:collection";

double START_TIME = DateTime.utc(2018).millisecondsSinceEpoch / 1000;

const SECOND_IN_DAY = 86400;

//index 0 is always price, index 2 is always time in epoch
//for backpack, index 1 is max price within the timespan
//for steam, index 1 is volume
const FILENAME = "data_dispenser_keyToUSD.csv";

Future<List<List<double>>> readAndFormat() async {
  List<dynamic> data = [];
  await new File(FILENAME).readAsString().then((String contents) {
    data = const CsvToListConverter().convert(contents);
  });
  List<List<double>> formattedData = [];
  for (int i = 0; i < data.length; i++) {
    if (data[i][2].toDouble() > START_TIME) {
      List<double> datapoint = [
        data[i][0].toDouble(),
        data[i][1].toDouble(),
        data[i][2].toDouble(),
      ];
      formattedData.add(datapoint);
    }
  }
  return formattedData;
}

void printTimeDifference(data) {
  for (int x = 1; x < data.length; x++) {
    print((data[x][2] - data[x - 1][2]) / SECOND_IN_DAY);
  }
}

double getAverage(data) {
  double sum = 0;
  for (int x = 0; x < data.length; x++) {
    sum += data[x][0];
  }
  // print(sum / data.length);
  return (sum / data.length);
}

//buy when price is stdAway stds from avg, sell opposite
//technically rolling over the last longMovingAvgDays data points not days
void stdMeanReversion(
    longMovingAvgDays, stdFactorBelow, stdFactorAbove, data) async {
  List<double> longRollingVals = [];
  double spent = 0;
  double profit = 0;
  int numBought = 0;
  int numSold = 0;
  int numSoldDates = 0;
  List<double> buys = [];
  List<double> buyTime = [];
  List<double> holdTime = [];
  SplayTreeMap<double, double> pnl = new SplayTreeMap<double, double>();
  SplayTreeMap<double, double> buyMap = new SplayTreeMap<double, double>();
  List<List<dynamic>> portfolioReturn = [];
  List<double> averageInstanceReturn = [];

  List<double> sellTime = [];

  double lastSellTime = data[longMovingAvgDays][2];
  double instanceSpent = 0;

  double stdSum = 0;

  for (int x = longMovingAvgDays; x < data.length; x++) {
    double price = data[x][0];
    double day = data[x][2];

    longRollingVals.clear();
    data
        .sublist(x - longMovingAvgDays, x)
        .forEach((row) => longRollingVals.add(row[0]));
    double longRollingAvg =
        longRollingVals.fold(0, (p, c) => p + c) / longMovingAvgDays;
    double longStd = Dispersion(Vector(longRollingVals)).std();
    stdSum += longStd;

    double dailypnl = profit;
    buys.forEach((k) => dailypnl += price - k);

    portfolioReturn.add([
      DateTime.fromMillisecondsSinceEpoch((day.toInt() * 1000))
          .toString(), //date
      dailypnl * 100 / spent, //net return %
      dailypnl, //net return USD
      price, //price
      buys.length //current portfolio size
    ]);

    // print(longRollingAvg.toString() + " , " + longStd.toString());
    //buy condition
    if (price < (longRollingAvg - (longStd * stdFactorBelow))) {
      // print((longRollingAvg - price) / (longStd * stdFactorBelow));
      int sharesToBuy =
          (pow((longRollingAvg - price) / (longStd * stdFactorBelow), 3))
              .ceil();
      for (int x = 0; x < sharesToBuy; x++) {
        spent += price;
        instanceSpent += price;
        numBought++;
        // print(x);
        buys.add(price);
        buyTime.add(day);
      }
      buyMap[day] = spent;
    }
    //sell condition
    if (price > (longRollingAvg + (longStd * stdFactorAbove))) {
      if (buys.length > 0) {
        numSold += buys.length;
        double instanceProfit = 0;
        buys.forEach((e) {
          profit += price - e;
          instanceProfit += price - e;
        });
        averageInstanceReturn.add(instanceProfit / instanceSpent);
        instanceSpent = 0;

        pnl[day] = profit;
        numSoldDates++;

        sellTime.add((day - lastSellTime) / SECOND_IN_DAY);
        lastSellTime = day;
      }
      buys.clear();
      buyTime.forEach((e) => holdTime.add((day - e) / SECOND_IN_DAY));
      buyTime.clear();
    }
  }
  print("");
  print("STD MEAN: " +
      longMovingAvgDays.toString() +
      "/" +
      stdFactorBelow.toString() +
      "/" +
      stdFactorAbove.toString());
  print("profit: " + profit.toString());
  print("amount spent: " + spent.toString());
  print("profit % : " + (profit * 100 / spent).toString());
  print("buys made: " + numBought.toString());
  print("sells made: " + numSold.toString() + "/" + numSoldDates.toString());
  print("avg std: " + (stdSum / (data.length - longMovingAvgDays)).toString());
  print("avg gap between sells: " +
      (sellTime.fold(0, (p, c) => p + c) / sellTime.length).toString());
  print("avg hold time: " +
      (holdTime.fold(0, (p, c) => p + c) / holdTime.length).toString());
  print("avg return %: " +
      (averageInstanceReturn.fold(0, (p, c) => p + c) *
              100 /
              averageInstanceReturn.length)
          .toString());
  // print("std of returns: " +
  // Dispersion(Vector(averageInstanceReturn)).std().toString());
  print("sharpe: " +
      ((profit / spent - 0.07) /
              Dispersion(Vector(averageInstanceReturn)).std())
          .toString());
  print("start time: " +
      DateTime.fromMillisecondsSinceEpoch(
              (data[longMovingAvgDays][2].toInt() * 1000))
          .toString());

  // List<List<dynamic>> pnlList = [];
  // pnl.keys.forEach((key) => pnlList.add([
  //       DateTime.fromMillisecondsSinceEpoch((key.toInt() * 1000)).toString(),
  //       pnl[key]
  //     ]));
  // List<List<dynamic>> buyList = [];
  // buyMap.keys.forEach((key) => buyList.add([
  //       DateTime.fromMillisecondsSinceEpoch((key.toInt() * 1000)).toString(),
  //       buyMap[key]
  //     ]));

  // await writeToCSV("pnl.csv", pnlList);
  // await writeToCSV("buys.csv", buyList);
  await writeToCSV("portfolio.csv", portfolioReturn);
}

void writeToCSV(filename, csv) async {
  String csvAsString = const ListToCsvConverter().convert(csv);
  File file = await File(filename);
  file.writeAsString(csvAsString);
}

//buy if 30d < 90d, sell if 30d > 90d
//technically rolling over the last 90 data points not days
void rollingMeanReversion(longMovingAvgDays, shortMovingAvgDays, data) {
  List<double> longRollingVals = [];
  List<double> shortRollingVals = [];
  double spent = 0;
  double profit = 0;
  int numBought = 0;
  int numSold = 0;
  List<double> buys = [];
  for (int x = longMovingAvgDays; x < data.length; x++) {
    double price = data[x][0];
    [longRollingVals, shortRollingVals].forEach((arr) => arr.clear());
    data
        .sublist(x - longMovingAvgDays, x)
        .forEach((row) => longRollingVals.add(row[0]));
    data
        .sublist(x - shortMovingAvgDays, x)
        .forEach((row) => shortRollingVals.add(row[0]));
    double longRollingAvg =
        longRollingVals.fold(0, (p, c) => p + c) / longMovingAvgDays;
    double shortRollingAvg =
        shortRollingVals.fold(0, (p, c) => p + c) / shortMovingAvgDays;

    // print(longRollingSum.toString() + " , " + shortRollingSum.toString());

    if (longRollingAvg > shortRollingAvg) {
      spent += price;
      numBought++;
      buys.add(price);
    }
    if (longRollingAvg < shortRollingAvg) {
      numSold += buys.length;
      buys.forEach((e) => profit += price - e);
      buys.clear();
    }
  }
  print("");
  print("ROLLING MEAN: " +
      longMovingAvgDays.toString() +
      "/" +
      shortMovingAvgDays.toString());
  print("profit: " + profit.toString());
  print("amount spent: " + spent.toString());
  print("profit % : " + (profit * 100 / spent).toString());
  print("buys made: " + numBought.toString());
  print("sells made: " + numSold.toString());
}

//mean reversion over all time, buy if below the mean
void meanReversion(avg, data) {
  double buyPrice = 0;
  bool bought = false;
  double amountSpent = 0;
  int purchasesMade = 0;
  double profit = 0;
  double boughtDay = 0;
  for (int x = 0; x < data.length; x++) {
    double price = data[x][0];
    double day = data[x][2] / 86400.0;
    //buy condition
    if (!bought && price < avg) {
      amountSpent += price;
      buyPrice = price;
      purchasesMade++;
      boughtDay = day;
      bought = true;
    }
    //sell condition
    if (bought && price > avg) {
      profit += price - buyPrice;
      bought = false;
      // print(profit.toString() + ", " + (day - boughtDay).toString());
      // print(profit);
    }
  }
  print("profit: " + profit.toString());
  print("amount spent: " + amountSpent.toString());
  print("profit % : " + (profit * 100 / amountSpent).toString());
  print("purchases made: " + purchasesMade.toString());
}

void printPrices(data) {
  for (int x = 0; x < data.length; x++) {
    print(data[x][0]);
  }
  // print(data.length);
}

void buildPriceInformation(startOffset, data) async {
  List<List<dynamic>> prices = [];

  for (int x = startOffset; x < data.length; x++) {
    prices.add([
      (DateTime.fromMillisecondsSinceEpoch((data[x][2].toInt() * 1000))
          .toString()),
      data[x][0]
    ]);
  }

  await writeToCSV("prices.csv", prices);
}

void wrapper() async {
  List<List<double>> keyData = await readAndFormat();

  // print(getAverage(keyData));
  // printTimeDifference(keyData);
  // printPrices(keyData);

  // meanReversion(getAverage(keyData), keyData);
  // rollingMeanReversion(100, 1, keyData);
  stdMeanReversion((keyData.length / 4).ceil(), 1, 0, keyData);
  // await buildPriceInformation(200, keyData);
}

void main() async {
  wrapper();
}
