import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Starbucks Analiz',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const AnaSayfa(),
    );
  }
}

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  int _secilenIndeks = 0;

  // Sayfaların listesi
  final List<Widget> _sayfalar = [
    const BugunSanaOzelSayfasi(), // Sayfa 1
    const SiparisSayfasi(), // Sayfa 2
    const AnalizSayfasi(), // Sayfa 3
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _sayfalar[_secilenIndeks],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _secilenIndeks,
        selectedItemColor: const Color(0xFF00704A), // Starbucks Yeşili
        onTap: (index) => setState(() => _secilenIndeks = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.star), label: 'Sana Özel'),
          BottomNavigationBarItem(icon: Icon(Icons.coffee), label: 'Sipariş'),
          BottomNavigationBarItem(
            icon: Icon(Icons.location_on),
            label: 'Şubeler',
          ),
        ],
      ),
    );
  }
}

class AnalizSayfasi extends StatefulWidget {
  const AnalizSayfasi({super.key});

  @override
  State<AnalizSayfasi> createState() => _AnalizSayfasiState();
}

class _AnalizSayfasiState extends State<AnalizSayfasi> {
  GoogleMapController? mapController;

  BitmapDescriptor markerRengi(int doluluk) {
    if (doluluk >= 75) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    } else if (doluluk >= 45) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
    } else {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şube Yoğunluk Analizi'),
        backgroundColor: const Color(0xFF00704A),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance.collection('Şubeler').snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final subeler = snapshot.data!.docs;

          Set<Marker> markers = {};

          for (var sube in subeler) {
            int d = double.parse(sube['doluluk'].toString()).toInt();

            markers.add(
              Marker(
                markerId: MarkerId(sube['isim']),
                position: LatLng(sube['lat'], sube['lng']),
                icon: markerRengi(d),
                infoWindow: InfoWindow(
                  title: sube['isim'],
                  snippet: "${sube['adres']} • Yoğunluk: %$d",
                ),
              ),
            );
          }

          return Column(
            children: [
              SizedBox(
                height: 300,
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(41.0422, 29.0053),
                    zoom: 11,
                  ),
                  markers: markers,
                  onMapCreated: (controller) {
                    mapController = controller;
                  },
                ),
              ),

              Expanded(
                child: ListView.builder(
                  itemCount: subeler.length,
                  itemBuilder: (context, index) {
                    var sube = subeler[index];

                    int d = double.parse(sube['doluluk'].toString()).toInt();

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        // SOL TARAFA YOL TARİFİ BUTONUNU EKLEDİK
                        leading: IconButton(
                          icon: const Icon(
                            Icons.directions,
                            color: Color(0xFF00704A),
                            size: 30,
                          ),
                          onPressed: () async {
                            final String subeAdi = sube['isim'];
                            final Uri url = Uri.parse(
                              "https://www.google.com/maps/search/?api=1&query=$subeAdi+Starbucks",
                            );

                            if (await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            )) {
                              // Harita başarıyla açıldı
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Harita uygulaması açılamadı",
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                        title: Text(
                          sube['isim'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(sube['adres']),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: d >= 75
                                ? Colors.red
                                : (d >= 45 ? Colors.orange : Colors.green),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            "%$d",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BugunSanaOzelSayfasi extends StatelessWidget {
  const BugunSanaOzelSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bugün Sana Özel"),
        backgroundColor: const Color(0xFF00704A),
      ),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('kampanyalar')
            .snapshots(),
        builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Hata oluştu"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          var kampanya = snapshot.data!.docs.first;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  color: Colors.orange.shade50,
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Icon(Icons.star, size: 40, color: Colors.orange),
                        const SizedBox(height: 10),
                        const Text(
                          "Özel Teklif!",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          kampanya['mesaj'],
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20), // Biraz boşluk bırakalım
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(
                              0xFF00704A,
                            ), // Starbucks Yeşili
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 30,
                              vertical: 12,
                            ),
                          ),
                          onPressed: () {
                            // Butona basıldığında olacaklar:
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text("Sipariş Onayı"),
                                  content: Text(
                                    "${kampanya['oran']}% indirimli siparişiniz hazırlanıyor!",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("Tamam"),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          child: const Text(
                            "Siparişi Onayla",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // --- ÖNCEKİ SİPARİŞİ TEKRARLA BÖLÜMÜ ---
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Sık Sipariş Ettiklerin",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: const Icon(
                      Icons.history,
                      color: Color(0xFF00704A),
                      size: 30,
                    ),
                    title: const Text("Iced Latte & Brownie"),
                    subtitle: const Text("En son 3 gün önce sipariş edildi"),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00704A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF00704A),
                                  ),
                                  SizedBox(width: 10),
                                  Text("Sipariş Tekrarlanıyor"),
                                ],
                              ),
                              content: const Text(
                                "Önceki siparişiniz başarıyla sepetinize eklendi ve hazırlanmaya başladı!",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text(
                                    "Tamam",
                                    style: TextStyle(
                                      color: Color(0xFF00704A),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                      child: const Text(
                        "Tekrarla",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              // --- SENİN İÇİN ÖNERİLER BAŞLIĞI (GERİ GELDİ) ---
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Senin İçin Öneriler",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const ListTile(
                leading: Icon(Icons.coffee, color: Color(0xFF00704A)),
                title: Text("Caramel Macchiato"),
                subtitle: Text("Sık tercih ettiğin lezzet"),
                trailing: Icon(Icons.arrow_forward_ios, size: 16),
              ),
            ],
          );
        },
      ),
    );
  }
}

class SiparisSayfasi extends StatefulWidget {
  const SiparisSayfasi({super.key});

  @override
  State<SiparisSayfasi> createState() => _SiparisSayfasiState();
}

class _SiparisSayfasiState extends State<SiparisSayfasi> {
  final Map<String, Map<String, dynamic>> sepet = {};

  final List<Map<String, dynamic>> urunler = [
    {
      'ad': 'Caramel Macchiato',
      'kategori': 'Sıcak İçecek',
      'fiyat': 145,
      'ikon': Icons.local_cafe,
    },
    {
      'ad': 'Iced Latte',
      'kategori': 'Soğuk İçecek',
      'fiyat': 130,
      'ikon': Icons.local_drink,
    },
    {'ad': 'Cookie', 'kategori': 'Yiyecek', 'fiyat': 95, 'ikon': Icons.cookie},
  ];

  int get toplamFiyat {
    int toplam = 0;

    sepet.forEach((key, urun) {
      toplam += (urun['fiyat'] as int) * (urun['adet'] as int);
    });

    return toplam;
  }

  void sepeteEkle(Map<String, dynamic> urun) {
    setState(() {
      if (sepet.containsKey(urun['ad'])) {
        sepet[urun['ad']]!['adet']++;
      } else {
        sepet[urun['ad']] = {...urun, 'adet': 1};
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("${urun['ad']} sepete eklendi"),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void sepetiGoster() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: sepet.isEmpty
              ? const Center(
                  child: Text("Sepetin boş", style: TextStyle(fontSize: 18)),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Sepetim",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...sepet.values.map(
                      (urun) => ListTile(
                        leading: Icon(
                          urun['ikon'],
                          color: const Color(0xFF00704A),
                        ),
                        title: Text(urun['ad']),
                        subtitle: Text("₺${urun['fiyat']}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                setState(() {
                                  if (urun['adet'] > 1) {
                                    urun['adet']--;
                                  } else {
                                    sepet.remove(urun['ad']);
                                  }
                                });
                                Navigator.pop(context);
                                sepetiGoster();
                              },
                            ),
                            Text(
                              urun['adet'].toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                setState(() {
                                  urun['adet']++;
                                });
                                Navigator.pop(context);
                                sepetiGoster();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      title: const Text(
                        "Toplam",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        "₺$toplamFiyat",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00704A),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text("Ödemeye Geç"),
                    ),
                  ],
                ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Menü ve Sipariş"),
        backgroundColor: const Color(0xFF00704A),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_bag),
                onPressed: sepetiGoster,
              ),
              if (sepet.isNotEmpty)
                Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(
                    radius: 9,
                    backgroundColor: Colors.red,
                    child: Text(
                      sepet.values
                          .fold<int>(0, (t, urun) => t + urun['adet'] as int)
                          .toString(),
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: urunler.length,
        itemBuilder: (context, index) {
          final urun = urunler[index];

          return Card(
            margin: const EdgeInsets.all(10),
            child: ListTile(
              leading: Icon(
                urun['ikon'],
                color: const Color(0xFF00704A),
                size: 32,
              ),
              title: Text(
                urun['ad'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text("${urun['kategori']} • ₺${urun['fiyat']}"),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00704A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => sepeteEkle(urun),
                child: const Text("Ekle"),
              ),
            ),
          );
        },
      ),
    );
  }
}
