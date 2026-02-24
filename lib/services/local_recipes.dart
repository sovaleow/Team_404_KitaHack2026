class LocalRecipeService {
  static const Map<String, List<String>> _recipeBook = {
    // MEAT & POULTRY
    'AYAM': [
      'Ayam Goreng Kunyit: Perap ayam dengan kunyit dan garam. Goreng bersama kacang panjang dan lobak merah untuk hidangan ringkas. / Marinate chicken with turmeric and salt. Stir-fry with long beans and carrots for a simple meal.',
      'Ayam Masak Merah: Goreng ayam yang diperap kunyit. Tumis pes cili, bawang, dan halia sehingga pecah minyak, kemudian tambah sos tomato. / Fry turmeric-marinated chicken. Sauté chili paste, onions, and ginger until oil separates, then add tomato sauce.',
    ],
    'CHICKEN': [
      'Ayam Goreng Kunyit: Perap ayam dengan kunyit dan garam. Goreng bersama kacang panjang dan lobak merah. / Marinate chicken with turmeric and salt. Stir-fry with long beans and carrots.',
      'Ayam Masak Merah: Goreng ayam yang diperap kunyit. Tumis pes cili, bawang, dan halia, kemudian tambah sos tomato. / Fry turmeric chicken. Sauté chili paste, onions, and ginger, then add tomato sauce.',
    ],
    'DAGING': [
      'Daging Masak Hitam: Masak daging dengan kicap pekat, kerisik, dan rempah ratus seperti bunga lawang dan kayu manis sehingga kuah pekat. / Cook beef with dark soy sauce, kerisik, and spices like star anise and cinnamon until the gravy thickens.',
      'Beef Stir-fry: Tumis daging yang dihiris nipis dengan halia, sos tiram, dan lada benggala untuk hidangan cepat. / Sauté thinly sliced beef with ginger, oyster sauce, and bell peppers for a quick dish.',
    ],
    'BEEF': [
      'Daging Masak Hitam: Masak daging dengan kicap pekat, kerisik, dan rempah ratus sehingga pekat. / Cook beef with dark soy sauce, toasted coconut (kerisik), and spices until thickened.',
      'Beef Stir-fry: Tumis daging dengan halia dan sos tiram. / Sauté beef with ginger and oyster sauce.',
    ],
    'KAMBING': [
      'Kari Kambing: Masak daging kambing dengan rempah kari, santan, kentang, dan daun kari sehingga empuk. / Cook mutton with curry spices, coconut milk, potatoes, and curry leaves until tender.',
    ],
    'LAMB': [
      'Mutton Curry: Masak kambing dengan rempah kari dan santan. / Cook mutton with curry spices and coconut milk.',
    ],
    'ITIK': [
      'Itik Salai Masak Lemak: Masak daging itik salai dengan santan, cili padi, dan kunyit hidup. / Cook smoked duck with coconut milk, bird\'s eye chilies, and fresh turmeric.',
    ],
    'DUCK': [
      'Smoked Duck Masak Lemak: Masak itik salai dalam kuah santan pedas. / Cook smoked duck in a spicy coconut gravy.',
    ],

    // SEAFOOD
    'IKAN': [
      'Ikan Bakar: Lumur ikan dengan pes sambal dan bakar di atas daun pisang untuk aroma yang wangi. / Rub fish with sambal paste and grill on banana leaves for a fragrant aroma.',
      'Ikan Masak Kicap: Tumis halia, bawang, dan cili. Tambah kicap manis dan masukkan ikan yang telah digoreng. / Sauté ginger, onions, and chilies. Add sweet soy sauce and toss in fried fish.',
    ],
    'FISH': [
      'Ikan Bakar: Bakar ikan dengan pes sambal. / Grill fish with sambal paste.',
      'Ikan Masak Kicap: Masak ikan goreng dalam kuah kicap and halia. / Cook fried fish in a soy sauce and ginger gravy.',
    ],
    'BILIS': [
      'Sambal Ikan Bilis: Goreng bilis sehingga garing. Tumis bawang besar dan pes cili, kemudian gaul bersama bilis. / Fry anchovies until crispy. Sauté large onions and chili paste, then toss with the anchovies.',
      'Bilis Fried Rice: Tumis bawang putih dan cili padi, masukkan nasi, telur, dan bilis goreng. / Sauté garlic and bird\'s eye chilies, add rice, egg, and fried anchovies.',
    ],
    'ANCHOVIES': [
      'Sambal Ikan Bilis: Tumis bilis goreng dengan sambal. / Sauté fried anchovies with sambal.',
      'Bilis Fried Rice: Nasi goreng dengan bilis garing. / Fried rice with crispy anchovies.',
    ],
    'SOTONG': [
      'Sotong Goreng Tepung: Salut sotong dengan tepung gandum dan tepung beras, kemudian goreng sehingga garing. / Coat squid with a mix of flour and rice flour, then deep fry until crispy.',
      'Sambal Sotong: Masak sotong dengan tumisan cili pedas dan air asam jawa. / Cook squid with a spicy chili sauté and tamarind juice.',
    ],
    'SQUID': [
      'Sambal Sotong: Masak sotong dalam sambal pedas. / Cook squid in a spicy sambal.',
    ],
    'UDANG': [
      'Udang Masak Lemak: Masak udang dengan santan, kunyit, and serai. Tambah hirisan nanas untuk rasa manis masam. / Cook prawns with coconut milk, turmeric, and lemongrass. Add pineapple slices for a sweet and sour taste.',
      'Butter Prawns: Goreng udang dengan mentega, daun kari, dan cili padi. / Fry prawns with butter, curry leaves, and bird\'s eye chilies.',
    ],
    'PRAWN': [
      'Butter Prawns: Udang goreng dengan mentega and daun kari. / Fried prawns with butter and curry leaves.',
    ],

    // VEGETABLES
    'SAWI': [
      'Sawi Tumis Air: Tumis bawang putih, masukkan air dan sawi. Pecahkan telur untuk rasa lebih sedap. / Sauté garlic, add water and mustard greens. Crack an egg in for extra flavor.',
      'Sawi Goreng Sos Tiram: Tumis sawi dengan sos tiram dan bawang putih dengan api besar. / Stir-fry mustard greens with oyster sauce and garlic over high heat.',
    ],
    'KANGKUNG': [
      'Kangkung Belacan: Tumis belacan, bawang putih, dan cili sehingga wangi, kemudian masukkan kangkung. / Sauté shrimp paste, garlic, and chilies until fragrant, then add the water spinach.',
    ],
    'BAYAM': [
      'Bayam Masak Lemak: Masak bayam dengan santan, ubi keledek, dan ikan bilis. / Cook spinach with coconut milk, sweet potato, and anchovies.',
    ],
    'KUBIS': [
      'Kubis Goreng Kunyit: Goreng hirisan kubis dengan sedikit kunyit, biji sawi, dan cili kering. / Stir-fry shredded cabbage with a pinch of turmeric, mustard seeds, and dried chilies.',
    ],
    'KOBIS': [
      'Kubis Goreng Kunyit: Masak kubis dengan kunyit dan biji sawi. / Cook cabbage with turmeric and mustard seeds.',
    ],
    'CABBAGE': [
      'Fried Cabbage: Tumis kubis dengan kunyit. / Stir-fry cabbage with turmeric.',
    ],
    'TERUNG': [
      'Terung Balado: Goreng terung sehingga lembut, kemudian gaulkan dengan sambal merah. / Fry eggplant until soft, then toss with red chili sambal.',
    ],
    'EGGPLANT': [
      'Terung Balado: Terung goreng dengan sambal. / Fried eggplant with sambal.',
    ],
    'BENDI': [
      'Bendi Goreng Belacan: Tumis bendi dengan belacan dan cili padi untuk rasa pedas yang menyengat. / Stir-fry okra with shrimp paste and bird\'s eye chilies for a spicy kick.',
    ],
    'OKRA': [
      'Fried Okra: Tumis bendi dengan belacan. / Stir-fry okra with belacan.',
    ],
    'KACANG': [
      'Kacang Panjang Goreng Telur: Masak kacang panjang dengan bawang putih dan pecahkan telur. / Cook long beans with garlic and scramble an egg into it.',
    ],
    'BROCCOLI': [
      'Stir-fry Broccoli: Tumis brokoli dengan bawang putih dan sos tiram. Tambah lobak merah untuk warna. / Sauté broccoli with garlic and oyster sauce. Add carrots for color.',
    ],
    'CARROT': [
      'Carrot Soup: Rebus lobak merah dengan bawang besar, kemudian kisar sehingga halus. / Boil carrots with onions, then blend until smooth.',
    ],
    'LOBAK': [
      'Sup Lobak: Masak lobak merah dalam sup. / Cook carrots in a soup.',
    ],
    'TOMATO': [
      'Tomato Egg: Tumis tomato dengan telur hancur. / Stir-fry tomatoes with scrambled eggs.',
    ],
    'TIMUN': [
      'Acar Timun: Perap timun dan lobak merah dengan cuka, gula, dan garam. / Pickle cucumbers and carrots with vinegar, sugar, and salt.',
    ],
    'CUCUMBER': [
      'Cucumber Salad: Jadikan timun sebagai salad atau acar. / Make cucumbers into a salad or pickle.',
    ],
    'CILI': [
      'Sambal Belacan: Tumbuk cili segar dengan belacan bakar dan limau kasturi. / Pound fresh chilies with toasted shrimp paste and calamansi lime.',
    ],
    'CHILI': [
      'Handmade Sambal: Buat sambal belacan sendiri. / Make your own sambal belacan.',
    ],
    'BAWANG': [
      'Bawang Goreng: Hiris nipis bawang merah dan goreng sehingga garing untuk dijadikan taburan. / Thinly slice shallots and fry until crispy to use as a garnish.',
    ],
    'ONION': [
      'Fried Onions: Goreng bawang untuk hiasan makanan. / Fry onions for food garnish.',
    ],
    'HALIA': [
      'Teh Halia: Rebus halia dengan air dan campurkan dengan susu manis. / Boil ginger with water and mix with sweet milk.',
    ],
    'GINGER': [
      'Ginger Tea: Buat air teh halia panas. / Make hot ginger tea.',
    ],

    // STAPLES
    'TELUR': [
      'Telur Dadar Special: Pukul telur dengan hirisan bawang, cili, dan daun sup sebelum digoreng. / Whisk eggs with sliced onions, chilies, and celery leaves before frying.',
    ],
    'EGG': [
      'Omelette: Masak telur dadar dengan bawang. / Cook an omelette with onions.',
    ],
    'ROTI': [
      'Roti Bakar: Bakar roti dan sapukan kaya serta mentega. / Toast bread and spread with kaya and butter.',
    ],
    'BREAD': [
      'Toasted Bread: Makan roti bakar dengan kaya. / Eat toasted bread with kaya.',
    ],
    'NASI': [
      'Nasi Goreng Kampung: Goreng nasi dengan belacan, bilis, dan kangkung. / Fry rice with shrimp paste, anchovies, and water spinach.',
    ],
    'RICE': [
      'Fried Rice: Masak nasi goreng. / Cook fried rice.',
    ],
    'SUSU': [
      'Air Susu Kurma: Kisar susu segar dengan kurma untuk minuman bertenaga. / Blend fresh milk with dates for an energetic drink.',
    ],
    'MILK': [
      'Milkshake: Kisar susu dengan buah-buahan. / Blend milk with fruits.',
    ],

    // FRUITS
    'BETIK': [
      'Papaya Salad: Hiris betik muda dan gaul dengan kacang tanah serta sos limau. / Shred young papaya and toss with peanuts and lime sauce.',
    ],
    'PAPAYA': [
      'Fruit Salad: Makan betik segar sebagai pencuci mulut. / Eat fresh papaya as a dessert.',
    ],
    'MANGGA': [
      'Mango Sticky Rice: Hidangkan mangga manis dengan nasi pulut dan santan pekat. / Serve sweet mango with glutinous rice and thick coconut milk.',
    ],
    'MANGO': [
      'Mango Smoothie: Kisar mangga dengan ais dan sedikit susu. / Blend mango with ice and a bit of milk.',
    ],
    'NANAS': [
      'Pajeri Nanas: Masak nanas dalam kuah kari yang pekat dan berkerisik. / Cook pineapple in a thick, toasted-coconut curry sauce.',
    ],
    'PINEAPPLE': [
      'Pineapple Tart: Jadikan nanas sebagai jem untuk tart. / Use pineapple as jam for tarts.',
    ],
    'TEMBIKAI': [
      'Jus Tembikai: Kisar tembikai dengan ais untuk minuman yang menyegarkan. / Blend watermelon with ice for a refreshing drink.',
    ],
    'WATERMELON': [
      'Watermelon Juice: Buat jus tembikai segar. / Make fresh watermelon juice.',
    ],
    'PISANG': [
      'Cekodok Pisang: Lenyek pisang, campur dengan tepung dan goreng sehingga bulat keemasan. / Mash bananas, mix with flour and deep fry until golden brown.',
    ],
    'BANANA': [
      'Banana Fritters: Buat pisang goreng garing. / Make crispy fried bananas.',
    ],
    'TEMPEH': [
      'Tempeh Goreng: Hiris tempeh, perap dengan ketumbar dan garam, kemudian goreng garing. / Slice tempeh, marinate with coriander and salt, then deep fry.',
    ],
    'TAHU': [
      'Tahu Masak Kicap: Goreng tahu dan tumis dengan kicap, bawang dan cili. / Fry tofu and sauté with soy sauce, onions and chilies.',
    ],
    'TOFU': [
      'Tahu Masak Kicap: Goreng tahu dan tumis dengan kicap, bawang dan cili. / Fry tofu and sauté with soy sauce, onions and chilies.',
    ],
    'PETAI': [
      'Sambal Tumis Udang Petai: Tumis pes cili dan bawang. Tambah udang dan petai. / Sauté chili paste and onions. Add prawns and petai.',
    ],
    'DURIAN': [
      'Serawa Durian: Masak isi durian dengan santan dan gula melaka. Hidangkan dengan pulut. / Cook durian flesh with coconut milk and palm sugar. Serve with pulut.',
    ],
  };

  static String getRecipeSuggestions(String itemName) {
    final name = itemName.toUpperCase();
    List<String> foundRecipes = [];

    _recipeBook.forEach((key, recipes) {
      if (name.contains(key)) {
        foundRecipes.addAll(recipes);
      }
    });

    if (foundRecipes.isEmpty) {
      return "Tiada resepi tempatan dijumpai untuk '$itemName'. Cuba gabungkan dengan bahan lain! / No local recipes found for '$itemName'. Try combining it with other ingredients!";
    }

    return "Suggested Recipes for $itemName:\n\n• " + foundRecipes.toSet().toList().join('\n\n• ');
  }
}
