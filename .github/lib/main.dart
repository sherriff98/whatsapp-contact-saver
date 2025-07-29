// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:contacts_service/contacts_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:device_apps/device_apps.dart';

void main() {
  runApp(WhatsAppContactManager());
}

class WhatsAppContactManager extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhatsApp Kişi Yöneticisi',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ContactManagerHome(),
    );
  }
}

class ContactManagerHome extends StatefulWidget {
  @override
  _ContactManagerHomeState createState() => _ContactManagerHomeState();
}

class _ContactManagerHomeState extends State<ContactManagerHome> {
  String status = 'Hazır - WhatsApp\'ı açmak için butona basın';
  bool isProcessing = false;
  int processedCount = 0;
  List<String> foundNumbers = [];
  Set<String> existingContacts = {};
  Set<String> usedCustomerIds = {};

  @override
  void initState() {
    super.initState();
    _loadExistingContacts();
  }

  // Mevcut rehber kişilerini yükle
  Future<void> _loadExistingContacts() async {
    try {
      if (await Permission.contacts.request().isGranted) {
        Iterable<Contact> contacts = await ContactsService.getContacts();
        existingContacts.clear();
        
        for (Contact contact in contacts) {
          if (contact.phones != null) {
            for (Item phone in contact.phones!) {
              String cleanNumber = _cleanPhoneNumber(phone.value ?? '');
              if (cleanNumber.isNotEmpty) {
                existingContacts.add(cleanNumber);
              }
            }
          }
        }
        
        setState(() {
          status = 'Rehberden ${existingContacts.length} kişi yüklendi';
        });
      }
    } catch (e) {
      setState(() {
        status = 'Rehber yüklenirken hata: $e';
      });
    }
  }

  // Telefon numarasını temizle
  String _cleanPhoneNumber(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.startsWith('0090')) {
      cleaned = '+90' + cleaned.substring(4);
    } else if (cleaned.startsWith('90') && cleaned.length == 12) {
      cleaned = '+' + cleaned;
    } else if (cleaned.startsWith('05') && cleaned.length == 11) {
      cleaned = '+90' + cleaned.substring(1);
    }
    return cleaned;
  }

  // WhatsApp'ı aç
  Future<void> _openWhatsApp() async {
    try {
      setState(() {
        status = 'WhatsApp açılıyor...';
      });

      bool launched = await DeviceApps.openApp('com.whatsapp');
      
      if (launched) {
        setState(() {
          status = 'WhatsApp açıldı. Lütfen ana ekrana dönün ve sohbetleri tara butonuna basın.';
        });
      } else {
        setState(() {
          status = 'WhatsApp açılamadı. Uygulama yüklü mü?';
        });
      }
    } catch (e) {
      setState(() {
        status = 'WhatsApp açılırken hata: $e';
      });
    }
  }

  // WhatsApp sohbet verilerini analiz et (simüle edilmiş)
  Future<void> _analyzeWhatsAppChats() async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
      status = 'WhatsApp sohbetleri taranıyor...';
      foundNumbers.clear();
      processedCount = 0;
    });

    try {
      // İzinleri kontrol et
      Map<Permission, PermissionStatus> permissions = await [
        Permission.contacts,
        Permission.storage,
      ].request();

      if (permissions[Permission.contacts] != PermissionStatus.granted) {
        setState(() {
          status = 'Rehber izni gerekli!';
          isProcessing = false;
        });
        return;
      }

      // WhatsApp verilerini simüle et (gerçek uygulamada WhatsApp database'i okunur)
      List<String> simulatedNumbers = await _getSimulatedWhatsAppNumbers();
      
      // +90 ile başlayan ve rehberde olmayan numaraları filtrele
      for (String number in simulatedNumbers) {
        String cleanNumber = _cleanPhoneNumber(number);
        
        if (cleanNumber.startsWith('+90') && 
            cleanNumber.length >= 13 && 
            !existingContacts.contains(cleanNumber)) {
          foundNumbers.add(cleanNumber);
        }
      }

      setState(() {
        status = '${foundNumbers.length} adet kayıtlı olmayan +90 numarası bulundu';
      });

    } catch (e) {
      setState(() {
        status = 'Analiz hatası: $e';
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  // WhatsApp numaralarını simüle et (test için)
  Future<List<String>> _getSimulatedWhatsAppNumbers() async {
    // Gerçek uygulamada burada WhatsApp database'i okunur
    // Bu simülasyon test amaçlıdır
    await Future.delayed(Duration(seconds: 2)); // Analiz süresini simüle et
    
    return [
      '+905551234567',
      '+905559876543',
      '+905552468135',
      '+905557891234',
      '+905553216549',
      '+905558765432',
      '+905554321987',
      '+905556547891',
      '05551111222', // Bu temizlenip +90 formatına çevrilecek
      '90552333444',  // Bu da
    ];
  }

  // Benzersiz müşteri ID üret
  String _generateUniqueCustomerId() {
    String customerId;
    do {
      customerId = (10000 + Random().nextInt(90000)).toString();
    } while (usedCustomerIds.contains(customerId));
    
    usedCustomerIds.add(customerId);
    return customerId;
  }

  // Numaraları rehbere ekle
  Future<void> _addNumbersToContacts() async {
    if (foundNumbers.isEmpty) {
      setState(() {
        status = 'Eklenecek numara bulunamadı!';
      });
      return;
    }

    setState(() {
      isProcessing = true;
      processedCount = 0;
      status = 'Rehbere ekleme başlıyor...';
    });

    try {
      for (String number in foundNumbers) {
        String customerId = _generateUniqueCustomerId();
        String contactName = 'Müşteri $customerId';
        
        // Kişiyi rehbere ekle
        Contact newContact = Contact(
          displayName: contactName,
          phones: [Item(label: 'mobile', value: number)],
        );

        await ContactsService.addContact(newContact);
        
        processedCount++;
        setState(() {
          status = 'Eklendi: $contactName ($number) - ${processedCount}/${foundNumbers.length}';
        });

        // Kısa bekleme (sistem yükünü azaltmak için)
        await Future.delayed(Duration(milliseconds: 500));
      }

      setState(() {
        status = '✅ Tamamlandı! ${processedCount} kişi rehbere eklendi.';
      });

      // Başarı mesajı göster
      _showSuccessDialog();

    } catch (e) {
      setState(() {
        status = 'Rehbere ekleme hatası: $e';
      });
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }

  // Başarı dialog'u göster
  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('✅ İşlem Tamamlandı'),
          content: Text(
            '$processedCount adet WhatsApp numarası başarıyla rehbere eklendi.\n\n'
            'Müşteri kodları otomatik olarak atandı.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _resetApp();
              },
              child: Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  // Uygulamayı sıfırla
  void _resetApp() {
    setState(() {
      foundNumbers.clear();
      processedCount = 0;
      usedCustomerIds.clear();
      status = 'Hazır - Yeni işlem için WhatsApp\'ı açın';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('WhatsApp Kişi Yöneticisi'),
        backgroundColor: Color(0xFF25D366), // WhatsApp yeşili
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF25D366), Color(0xFF128C7E)],
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo area
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.contacts,
                      size: 60,
                      color: Color(0xFF25D366),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'WhatsApp Kişi Yöneticisi',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF128C7E),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 30),

              // Status card
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                ),
              ),

              SizedBox(height: 30),

              // Action buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isProcessing ? null : _openWhatsApp,
                      icon: Icon(Icons.chat, color: Colors.white),
                      label: Text(
                        'WhatsApp\'ı Aç',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF128C7E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isProcessing ? null : _analyzeWhatsAppChats,
                      icon: isProcessing 
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(Icons.search, color: Colors.white),
                      label: Text(
                        isProcessing ? 'Taranıyor...' : 'Sohbetleri Tara',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (isProcessing || foundNumbers.isEmpty) ? null : _addNumbersToContacts,
                      icon: Icon(Icons.person_add, color: Colors.white),
                      label: Text(
                        'Rehbere Ekle (${foundNumbers.length})',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: foundNumbers.isEmpty ? Colors.grey : Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(height: 30),

              // Info card
              Container(
                padding: EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.info_outline, color: Colors.white, size: 24),
                    SizedBox(height: 8),
                    Text(
                      'Bu uygulama WhatsApp sohbetlerinizdeki kayıtlı olmayan +90 numaralarını bulur ve otomatik olarak "Müşteri XXXXX" formatında rehbere ekler.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// pubspec.yaml için gerekli dependencies:
/*
dependencies:
  flutter:
    sdk: flutter
  contacts_service: ^0.6.3
  permission_handler: ^10.4.3
  device_apps: ^2.2.0
  path_provider: ^2.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^2.0.0

flutter:
  uses-material-design: true
*/
