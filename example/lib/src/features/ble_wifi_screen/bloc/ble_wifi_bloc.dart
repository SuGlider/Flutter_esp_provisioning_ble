import 'dart:convert';
import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'package:example/src/features/services/transport_ble.dart';
import 'package:flutter_ble_lib_ios_15/flutter_ble_lib.dart';
import 'package:meta/meta.dart';
import 'package:logger/logger.dart';
import 'package:esp_provisioning_ble/esp_provisioning.dart';

part 'ble_wifi_event.dart';
part 'ble_wifi_state.dart';

class BleWifiBloc extends Bloc<BleWifiEvent, BleWifiState> {
  late EspProv prov;
  Logger log = Logger(printer: PrettyPrinter());
  List<Map<String, dynamic>> foundedNetworks = [];

  BleWifiBloc() : super(BleWifiInitial()) {
    on<BleWifiInitialEvent>((event, emit) {
      prov = EspProv(
        transport: TransportBLE(event.peripheral),
        security: Security1(pop: event.pop),
      );
    });

    on<BleWifiEstablishedConnectionEvent>((event, emit) async {
      var sessionStatus = await prov.establishSession();
      log.d("Session Status = $sessionStatus");
      (sessionStatus)
          ? emit(BleWifiEstablishedConnectionState())
          : emit(BleWifiEstablishedConnectionFailedState());
    });

    on<BleWifiScanWifiNetworksEvent>((event, emit) async {
      try {
        var listWifi = await prov.startScanWiFi();
        log.d('Found ${listWifi.length} WiFi networks');
        for (var obj in listWifi) {
          log.d('WiFi network: ${obj.ssid}');
          Map<String, dynamic> networksMap = {
            "ssid": obj.ssid,
            "instance": obj,
          };
          foundedNetworks.add(networksMap);
        }
        emit(BleWifiScannedNetworksState(foundedNetworks: foundedNetworks));
      } catch (e) {
        log.e('Error scan WiFi network: $e');
      }
    });

    on<BleWifiSendConfigEvent>((event, emit) async {
      var customAnswerBytes = await prov.sendReceiveCustomData(
        Uint8List.fromList(
          utf8.encode(event.customSendMessage),
        ),
      );
      var customAnswer = utf8.decode(customAnswerBytes);
      log.i("Custom data answer: $customAnswer");
      await prov.sendWifiConfig(ssid: event.ssid, password: event.password);
      await prov.applyWifiConfig();
      emit(BleWifiSentConfigState());
    });

    on<BleWifiLoadingEvent>((event, emit) {
      emit(BleWifiLoadingState());
    });
  }
}
