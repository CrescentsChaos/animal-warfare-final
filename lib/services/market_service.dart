import 'dart:math' as math;
import 'package:animal_warfare/game/time_service.dart';

class MarketService {
  /// Returns a multiplier for an item based on the current game date.
  /// Used to determine the current market price.
  static double getPriceMultiplier(String itemId, GameTime time) {
    // Generate a pseudo-random multiplier between 0.6 and 1.5
    // based on the daily seed and item ID so it stays constant throughout the day.
    final seed = time.dailySeed ^ itemId.hashCode;
    final random = math.Random(seed);

    // Base fluctuation between 0.8 and 1.2
    double multiplier = 0.8 + (random.nextDouble() * 0.4);

    // Day of the week bias
    // Weekends (Fri-Sun) are more volatile and slightly higher demand/prices
    final weekday = time.weekday;
    if (weekday >= 5) {
      // 5=Fri, 6=Sat, 7=Sun
      multiplier += (random.nextDouble() * 0.2); // Potential for higher prices
      if (random.nextDouble() < 0.2)
        multiplier += 0.1; // Extra weekend spike chance
    } else {
      multiplier -= (random.nextDouble() * 0.05); // Workdays slightly lower
    }

    // Small chance for a major spike (up to 1.6+)
    if (random.nextDouble() < 0.1) {
      multiplier += 0.2 + (random.nextDouble() * 0.3);
    }
    // Small chance for a deep discount (down to 0.4)
    else if (random.nextDouble() < 0.1) {
      multiplier -= 0.2 + (random.nextDouble() * 0.2);
    }

    // Clamp just in case
    return multiplier.clamp(0.4, 2.0);
  }

  /// Calculates the actual current price of an item given its base price.
  static int getCurrentPrice(String itemId, int basePrice, GameTime time) {
    final multiplier = getPriceMultiplier(itemId, time);
    return (basePrice * multiplier).round();
  }

  /// Calculates the sell price (typically 50% of the current buy price).
  static int getSellPrice(String itemId, int basePrice, GameTime time) {
    final currentBuyPrice = getCurrentPrice(itemId, basePrice, time);
    return (currentBuyPrice * 0.5).round();
  }

  /// Returns the price history for the last [days] days to render charts.
  static List<double> getPriceHistory(
    String itemId,
    int basePrice,
    GameTime time, {
    int days = 7,
  }) {
    List<double> history = [];
    // We need to work backwards. We'll approximate by modifying the daily seed.
    // In a real system, we might want a utility to subtract days from GameTime accurately.
    // Since GameTime has a dailySeed defined as `year * 10000 + month * 100 + day`,
    // this simplistic backwards step will break across month boundaries slightly
    // (e.g. 20240101 -> 20240100 instead of 20231231) but for a seeded RNG effect,
    // it perfectly suffices for generating consistent charting data without date math complexity.

    int currentSeed = time.dailySeed;

    for (int i = days - 1; i >= 0; i--) {
      // Create a deterministic offset seed for the past days.
      final pastSeed = currentSeed - i;
      final seed = pastSeed ^ itemId.hashCode;
      final random = math.Random(seed);

      double multiplier = 0.8 + (random.nextDouble() * 0.4);
      if (random.nextDouble() < 0.1) {
        multiplier += 0.2 + (random.nextDouble() * 0.2);
      } else if (random.nextDouble() < 0.1) {
        multiplier -= 0.2 + (random.nextDouble() * 0.2);
      }

      history.add(basePrice * multiplier.clamp(0.4, 1.8));
    }

    return history;
  }

  /// Calculates deterministic black market stock (3-5 items) for the day.
  /// These items are deeply discounted but sometimes fake prices.
  static List<String> getBlackMarketStock(
    List<String> allItemIds,
    GameTime time,
  ) {
    if (allItemIds.isEmpty) return [];

    final seed = time.dailySeed ^ 0x0B1AC4;
    final random = math.Random(seed);

    // 3 to 5 items
    int numItems = 3 + random.nextInt(3);
    final List<String> stock = [];

    for (int i = 0; i < numItems; i++) {
      final randomItem = allItemIds[random.nextInt(allItemIds.length)];
      if (!stock.contains(randomItem)) {
        stock.add(randomItem);
      }
    }

    return stock;
  }

  /// Calculates a deterministic black market price multiplier.
  static double getBlackMarketMultiplier(String itemId, GameTime time) {
    // Different seed from normal market
    final seed = time.dailySeed ^ itemId.hashCode ^ 0x666;
    final random = math.Random(seed);

    // Most items are heavily discounted (0.2 to 0.6)
    // But some are massively overpriced SCAMS (2.0 to 5.0)
    if (random.nextDouble() < 0.2) {
      // 20% chance of a scam
      return 2.0 + (random.nextDouble() * 3.0);
    }

    return 0.2 + (random.nextDouble() * 0.4);
  }

  /// Opens a mystery box and returns a string detailing the result.
  /// Modifies [inventory] and [money] directly based on the reward.
  static String openMysteryBox(
    String tier,
    Map<String, int> inventory,
    int currentMoney,
    void Function(int) addMoney,
    void Function(String, int) addLoot,
  ) {
    final random = math.Random();
    final roll = random.nextDouble();

    // Costs: Bronze=5,000 | Silver=20,000 | Gold=100,000
    int cost = 5000;
    int basePayout = 1000;
    if (tier == 'silver_box') {
      cost = 20000;
      basePayout = 5000;
    } else if (tier == 'gold_box') {
      cost = 100000;
      basePayout = 30000;
    }

    if (roll < 0.45) {
      // 45% Scam! You got basically nothing.
      int returnMoney = (basePayout * (0.05 + random.nextDouble() * 0.1))
          .round();
      addMoney(returnMoney);
      return "SCAM! The box contained junk worth ${returnMoney}G. You lost ${cost - returnMoney}G.";
    } else if (roll < 0.80) {
      // 35% Slight loss or break even
      int returnMoney = (cost * (0.5 + random.nextDouble() * 0.7)).round();
      addMoney(returnMoney);
      if (returnMoney >= cost) {
        return "Not bad! The box contained exactly ${returnMoney}G.";
      } else {
        return "Ouch. The box contained ${returnMoney}G. You lost a bit.";
      }
    } else if (roll < 0.95) {
      // 15% Good profit (Money or Item)
      if (random.nextBool()) {
        int returnMoney = (cost * (1.5 + random.nextDouble())).round();
        addMoney(returnMoney);
        return "NICE! You found rare artifacts worth ${returnMoney}G!";
      } else {
        // Give a random decent talisman
        const items = [
          'leftovers',
          'life_orb',
          'focus_sash',
          'choice_band',
          'choice_specs',
          'choice_scarf',
        ];
        final item = items[random.nextInt(items.length)];
        addLoot(item, 1);
        return "GREAT! The box contained a rare ${item.replaceAll('_', ' ')}!";
      }
    } else {
      // 5% JACKPOT!
      if (random.nextDouble() < 0.8) {
        // Large Money
        int returnMoney = cost * 10;
        addMoney(returnMoney);
        return "JACKPOT!!! The box contained a fortune of ${returnMoney}G!!!";
      } else {
        // Super Rare Item (e.g. Master Rod - wait, is there one? Let's use Super Rod)
        addLoot('super_rod', 1);
        return "ULTIMATE JACKPOT!!! You found a legendary SUPER ROD in the box!!!";
      }
    }
  }
}
