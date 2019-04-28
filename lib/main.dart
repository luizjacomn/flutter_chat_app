import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart';

Future main() async {
  runApp(MaterialApp(
    title: 'ChatApp',
    debugShowCheckedModeBanner: false,
    theme: dark,
    home: ChatScreen(),
  ));
}

final ThemeData dark = ThemeData(
  backgroundColor: Colors.blueGrey[900],
  cardColor: Colors.blueGrey[800],
  highlightColor: Colors.grey[400],
  primaryColor: Colors.teal,
  accentColor: Colors.tealAccent,
  hintColor: Colors.grey[200],
  disabledColor: Colors.blueGrey[500],
  primaryColorLight: Colors.white,
  fontFamily: 'Raleway',
);

final _googleSignIn = GoogleSignIn();

final _auth = FirebaseAuth.instance;

final messagesCollection = 'messages';
final textField = "text";
final imgUrlField = "imgUrl";
final fromField = "from";
final fromImgUrlField = "fromImgUrl";
final timeStampField = "timestamp";

Future<Null> _ensureUserIsLogged() async {
  GoogleSignInAccount user = _googleSignIn.currentUser;

  if (user == null) user = await _googleSignIn.signInSilently();

  if (user == null) user = await _googleSignIn.signIn();

  if (await _auth.currentUser() == null) {
    GoogleSignInAuthentication credentials =
        await _googleSignIn.currentUser.authentication;
    await _auth.signInWithGoogle(
      idToken: credentials.idToken,
      accessToken: credentials.accessToken,
    );
  }
}

void _handleSubmmited(String text) async {
  await _ensureUserIsLogged();
  _sendMessage(text: text);
}

void _sendMessage({String text, String imgUrl}) {
  Firestore.instance.collection(messagesCollection).add({
    textField: text != null ? text.trim() : null,
    imgUrlField: imgUrl,
    fromField: _googleSignIn.currentUser.displayName,
    fromImgUrlField: _googleSignIn.currentUser.photoUrl,
    timeStampField: DateTime.now().millisecondsSinceEpoch.toString(),
  });
}

class ChatScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: Scaffold(
        backgroundColor: Theme.of(context).backgroundColor,
        appBar: AppBar(
          centerTitle: true,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                Icons.question_answer,
              ),
              Padding(
                padding: EdgeInsets.only(left: 10.0),
                child: Text(
                  'ChatApp',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Ubuntu',
                  ),
                ),
              ),
            ],
          ),
          elevation: 4.0,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(
                stream: Firestore.instance
                    .collection(messagesCollection)
                    .snapshots(),
                builder: (context, snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.none:
                    case ConnectionState.waiting:
                      return Center(
                        child: CircularProgressIndicator(
                          backgroundColor: Theme.of(context).hintColor,
                        ),
                      );
                    default:
                      return ListView.builder(
                        reverse: true,
                        itemCount: snapshot.data.documents.length,
                        itemBuilder: (context, index) {
                          List reversed = snapshot.data.documents;
                          reversed.sort((a, b) =>
                              b[timeStampField].compareTo(a[timeStampField]));
                          return ChatMessage(reversed[index].data);
                        },
                      );
                  }
                },
              ),
            ),
            Divider(
              height: 2.0,
              color: Theme.of(context).hintColor,
            ),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
              ),
              child: TextComposer(),
            ),
          ],
        ),
      ),
    );
  }
}

class TextComposer extends StatefulWidget {
  @override
  _TextComposerState createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  final _messageController = TextEditingController();
  bool _isWritting = false;

  void _resetField() {
    _messageController.clear();
    setState(() {
      _isWritting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconTheme(
      data: IconThemeData(color: Theme.of(context).accentColor),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: <Widget>[
            Container(
              child: IconButton(
                  icon: Icon(Icons.photo_camera),
                  onPressed: () async {
                    await _ensureUserIsLogged();

                    File file =
                        await ImagePicker.pickImage(source: ImageSource.camera);

                    if (file == null) return;

                    StorageUploadTask task = FirebaseStorage.instance
                        .ref()
                        .child(_googleSignIn.currentUser.id + '_' +
                            DateTime.now().millisecondsSinceEpoch.toString())
                        .putFile(file);

                    _sendMessage(
                        imgUrl: (await task.future).downloadUrl.toString());
                  }),
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                textInputAction: TextInputAction.send,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (text) {
                  setState(() {
                    _isWritting = text.isNotEmpty;
                  });
                },
                onSubmitted: (text) {
                  _handleSubmmited(text);
                  _resetField();
                },
                style: TextStyle(color: Theme.of(context).primaryColorLight),
                decoration: InputDecoration.collapsed(
                    hintText: 'Enviar uma mensagem',
                    hintStyle: TextStyle(color: Theme.of(context).hintColor)),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Theme.of(context).platform == TargetPlatform.iOS
                  ? CupertinoButton(
                      child: Text('Enviar'),
                      onPressed: _isWritting
                          ? () {
                              _handleSubmmited(_messageController.text);
                              _resetField();
                            }
                          : null,
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.send,
                      ),
                      onPressed: _isWritting
                          ? () {
                              _handleSubmmited(_messageController.text);
                              _resetField();
                            }
                          : null,
                    ),
            )
          ],
        ),
      ),
    );
  }
}

class ChatMessage extends StatelessWidget {
  final Map<String, dynamic> data;

  ChatMessage(this.data);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5.0),
        color: Theme.of(context).cardColor,
      ),
      margin: const EdgeInsets.symmetric(horizontal: 15.0, vertical: 15.0),
      child: Row(
        children: <Widget>[
          Container(
            margin: const EdgeInsets.only(right: 16.0),
            child: data[fromImgUrlField] == null
                ? CircleAvatar(
                    backgroundColor: Theme.of(context).accentColor,
                    child: Text(data[fromField].substring(0, 1)),
                  )
                : CircleAvatar(
                    backgroundImage: NetworkImage(data[fromImgUrlField]),
                  ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data[fromField],
                  style: TextStyle(
                      color: Theme.of(context).hintColor,
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold),
                ),
                Container(
                  margin: const EdgeInsets.only(top: 5.0),
                  child: data[imgUrlField] == null
                      ? Text(
                          data[textField],
                          style: TextStyle(
                            color: Theme.of(context).primaryColorLight,
                            fontSize: 15.0,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Image.network(
                          data[imgUrlField],
                          width: 250.0,
                        ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
