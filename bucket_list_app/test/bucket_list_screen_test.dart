//import 'package:flutter_test/flutter_test.dart';
//import 'package:bucket_list_app/screens/bucket_list_screen.dart';
//import 'package:flutter/material.dart';
//import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
//import 'package:bucket_list_app/models/bucket_list.dart';
//import 'package:cloud_firestore/cloud_firestore.dart';

//void main() {
  //testWidgets('renders bucket list title and FAB', (WidgetTester tester) async {
    //final mockUserId = 'test-user-123';
    //final fakeFirestore = FakeFirebaseFirestore();

    // Add fake bucket list doc to Firestore
    //final bucketListDoc = await fakeFirestore.collection('bucket_lists').add({
      //'title': 'Test List',
      //'userId': mockUserId,
      //'items': [],
    //});

    //final mockBucketList = BucketList(
      //id: bucketListDoc.id,
      //title: 'Test List',
      //userId: mockUserId,
      //items: [],
    //);

    //await tester.pumpWidget(MaterialApp(
      //home: BucketListScreen(
        //bucketList: mockBucketList,
//        onUpdate: () {},
 //     ),
//    ));

 //   expect(find.text('Test List'), findsOneWidget);
//    expect(find.byIcon(Icons.add), findsOneWidget);
//  });
//}
