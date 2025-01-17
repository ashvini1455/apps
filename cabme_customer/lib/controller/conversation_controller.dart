import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:VEIDI/constant/constant.dart';
import 'package:VEIDI/constant/send_notification.dart';
import 'package:VEIDI/model/user_model.dart';
import 'package:VEIDI/service/api.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;

import '../constant/show_toast_dialog.dart';

class ConversationController extends GetxController {
  @override
  void onInit() {
    getArgument();
    getUsrData();
    super.onInit();
  }

  RxInt senderId = 0.obs;
  RxInt receiverId = 0.obs;
  RxInt orderId = 0.obs;
  RxString senderName = "".obs;
  RxString senderPhoto = "".obs;
  RxString receiverName = "".obs;
  RxString receiverPhoto = "".obs;
  RxString receiverToken = "".obs;

  getArgument() async {
    dynamic argumentData = Get.arguments;
    if (argumentData != null) {
      receiverId.value = argumentData['receiverId'];
      orderId.value = argumentData['orderId'];
      receiverName.value = argumentData['receiverName'];
      receiverPhoto.value = argumentData['receiverPhoto'];

      await getToken(receiverId.value);
    }
    update();
  }

  getUsrData() {
    UserModel userModel = Constant.getUserData();
    senderId.value = userModel.data!.id!;
    senderPhoto.value = userModel.data!.photoPath!;
    senderName.value = "${userModel.data!.prenom!} ${userModel.data!.nom!}";
  }

  Future<dynamic> getToken(int receiverId) async {
    try {
      Map<dynamic, dynamic> bodyParams = {
        'id_user': receiverId,
        'cat_user': "driver",
      };
      final response = await http.post(Uri.parse(API.getFcmToken),
          headers: API.header, body: jsonEncode(bodyParams));
      Map<String, dynamic> responseBody = json.decode(response.body);

      if (response.statusCode == 200 && responseBody['success'] == "success") {
        receiverToken.value = responseBody['data']['fcm_id'];
      } else if (response.statusCode == 200 &&
          responseBody['success'] == "failed") {
        ShowToastDialog.showToast(responseBody['error']);
      } else {
        ShowToastDialog.showToast(
            'Something want wrong. Please try again later');
        throw Exception('Failed to load album');
      }
    } on TimeoutException catch (e) {
      ShowToastDialog.showToast(e.message.toString());
    } on SocketException catch (e) {
      ShowToastDialog.showToast(e.message.toString());
    } on Error catch (e) {
      ShowToastDialog.showToast(e.toString());
    } catch (e) {
      ShowToastDialog.showToast(e.toString());
    }
    return null;
  }

  sendMessage(String message, Url url, String videoThumbnail, String type) {
    String id = Constant.getUuid();
    Map<String, dynamic> messageData = {
      'id': id,
      'senderId': senderId.value,
      'receiverId': receiverId.value,
      'message': message,
      'orderId': orderId.value,
      'created': DateTime.now(),
      'videoThumbnail': videoThumbnail,
      'url': url.toJson(),
      'type': type,
    };

    String idCollection =
        "${senderId.value < receiverId.value ? senderId.value : receiverId.value}-${orderId.value}-${senderId.value < receiverId.value ? receiverId.value : senderId.value}";

    Map<String, dynamic> inboxData = {
      'id': idCollection,
      'senderId': senderId.value,
      'receiverId': receiverId.value,
      'message': message,
      'orderId': orderId.value,
      'created': DateTime.now(),
      'senderName': senderName.value,
      'receiverName': receiverName.value,
      'senderPhoto': senderPhoto.value,
      'receiverPhoto': receiverPhoto.value
    };

    Constant.conversation.doc(idCollection).set(inboxData);
    Constant.conversation
        .doc(idCollection)
        .collection("thread")
        .doc(id)
        .set(messageData);

    Map<String, dynamic> notificationData = {
      'id': id,
      'senderId': senderId.value,
      'receiverId': receiverId.value,
      'message': message,
      'orderId': orderId.value,
      'videoThumbnail': videoThumbnail,
      'url': url.toJson(),
      'type': type,
    };

    Map<String, dynamic> payload = <String, dynamic>{
      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      'id': '1',
      'status': 'done',
      'message': notificationData,
      'isGroup': false,
    };
    SendNotification.sendMessageNotification(
        receiverToken.value, senderName.value, message, payload);
  }
}
