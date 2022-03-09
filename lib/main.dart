import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:temp_webview_app/modal_progress_hud.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool isLoading = false;
  //TextEditingController textEditingController = TextEditingController(text: "https://instancylivesites.blob.core.windows.net/enterprisedemocontent/content/publishfiles/9e84f496-30d1-4bd4-addb-a5deb178866d/6934048d-7acf-4ab7-9249-e14dfce7495f.zip");
  TextEditingController textEditingController = TextEditingController(text: "https://instancylivesites.blob.core.windows.net/upgradedenterprise/content/publishfiles/ea5c7ca4-3402-4256-b2ae-6683ec6673a4/cc75fbcc-7f84-45c1-a737-f4022dc6a242.zip");

  File? zipFile;

  Future<bool> requestPermission(Permission permission, String permissionString) async {
    var status = await permission.status;
    if (status.isRestricted) {
      status = await permission.request();
    }

    if (status.isDenied) {
      status = await permission.request();
    }

    if(status.isGranted) return true;

    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.green,
          content: Text('Please add permission for app to $permissionString'),
        ),
      );
    }

    return false;
  }

  Future<File?> downloadFromUrl(String url, String filepath) async {
    final http.Response response = await http.get(Uri.parse(url));

    print("Response:" + response.bodyBytes.toString());
    print("Response Body:" + response.body);


    if (response.contentLength == 0) {
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("Dowload Failed: File Doesn't contains data")));
      return null;
    }
    else {
      try {
        File file = File(filepath);
        if(!file.existsSync()) file.createSync(recursive: true);
        file = await file.writeAsBytes(response.bodyBytes);
        return file;
      }
      catch(e) {
        print("Error in Saving File:${e}");
      }
    }
  }

  Future<void> downloadFileFromUrlButtonClick(String url) async {
    bool isManagePermissionGranted = await requestPermission(Permission.manageExternalStorage, "Manage Exteral Storage");
    bool isStoragePermissionGranted = await requestPermission(Permission.storage, "Read and Write Exteral Storage");

    if(isManagePermissionGranted && isStoragePermissionGranted) {
      setState(() {
        isLoading = true;
      });

      String fileName = url.substring(url.lastIndexOf("/") + 1);

      Directory? directory = await getExternalStorageDirectory();
      if(directory != null) {
        String directoryPath = directory.path;
        directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
        directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
        directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
        directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
        directoryPath += "/My Custom Downloads";

        String path = directoryPath + "/$fileName";
        if(File(path).existsSync()) {
          ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("File Already Exist")));
        }
        else {
          File? file = await downloadFromUrl(url, path);
          if(file != null) {
            zipFile = file;
            ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(const SnackBar(content: Text("File Dowloaded Successfully")));
          }
          else {
            ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(const SnackBar(content: Text("File Creation Failed")));
          }
        }
      }

      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> extractZipFile() async {
    if(zipFile == null) return;

    setState(() {
      isLoading = true;
    });

    String destinationPath = zipFile!.path.substring(0, zipFile!.path.lastIndexOf("."));

    final Directory destinationDir = Directory(destinationPath);
    try {
      // Read the Zip newFile from disk.
      final Uint8List bytes = zipFile!.readAsBytesSync();

      // Decode the Zip newFile
      final Archive archive = ZipDecoder().decodeBytes(bytes);

      String lastFolderPath = "";

      // Extract the contents of the Zip archive to disk.
      for (final file in archive) {
        final filename = file.name;
        print("IsFile:${file.isFile}, Path:${file.name}");
        if (file.isFile) {
          final data = file.content as List<int>;
          File  newFile = File(destinationPath + "/" + filename);
          newFile = await newFile.create(recursive: true);
          newFile = await newFile.writeAsBytes(data);
        }
        else {
          lastFolderPath = file.name;
          Directory(destinationPath + "/" + filename).createSync(recursive: true);
        }
      }

      //await ZipFile.extractToDirectory(zipFile: zipFile!, destinationDir: destinationDir);
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("Zip File Extracted on Path $destinationPath")));
    }
    catch (e) {
      print(e);
      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("Error in Extracting Zip File:${e}")));
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> openWebView(String path) async {

    print("File Path:${path}");
    //FlutterWebviewPlugin().launch(path, withLocalUrl: true, allowFileURLs: true, withLocalStorage: true);

    /*Navigator.push(context, MaterialPageRoute(builder: (BuildContext context) {
      return Scaffold(
        body: WebView(
          initialUrl: "https://www.google.com",
          onPageStarted: (String value) {
            print("PageLoaded:${value}");
          },
          onWebViewCreated: (WebViewController controller) {
            print("onWebViewCreated:${controller}");
            //controller.loadFile("file://" + path);
          },
          onWebResourceError: (WebResourceError error) {
            print("onWebResourceError:${error.description}");
          },
        ),
      );
    }));*/

    Navigator.push(context, MaterialPageRoute(
      builder: (BuildContext context) {
        return WebviewScaffold(
          persistentFooterButtons: [],
          url: path,
          withLocalUrl: true,
          withLocalStorage: true,
          appCacheEnabled: true,
          displayZoomControls: true,
          ignoreSSLErrors: true,
          allowFileURLs: true,
          /*javascriptChannels: <JavascriptChannel>{
            JavascriptChannel(
              name: 'MeetMsg',
              onMessageReceived: (JavascriptMessage msg) {
                print("Message Got in MeetMsg channel:${msg.message}");
              },
            ),
          },*/
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.black),
            actionsIconTheme: const IconThemeData(color: Colors.black),
            title: const Text("Webview", style: TextStyle(color: Colors.black),),
          ),
        );
      }
    ));
  }

  @override
  Widget build(BuildContext context) {
    print("Zip File:${zipFile}");

    return SafeArea(
      child: ModalProgressHUD(
        inAsyncCall: isLoading,
        progressIndicator: const CircularProgressIndicator(color: Colors.blue,),
        child: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            title: const Text("Home Page"),
          ),
          body: Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text("Test Your Download links Here"),

                TextField(
                  controller: textEditingController,
                  decoration: const InputDecoration(
                    hintText: "Enter Url"
                  ),
                ),
                getButton("Download File From Url", () {
                  if(textEditingController.text.isNotEmpty) {
                    downloadFileFromUrlButtonClick(textEditingController.text);
                  }
                  else {
                    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("Please Enter a Url")));
                  }
                },),
                getButton("Extract File", () async {
                  if(textEditingController.text.isEmpty) {
                    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("Please Enter a Url")));
                    return;
                  }
                  String fileName = textEditingController.text.substring(textEditingController.text.lastIndexOf("/") + 1);

                  Directory? directory = await getExternalStorageDirectory();
                  if(directory != null) {
                    String directoryPath = directory.path;
                    directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
                    directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
                    directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
                    directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
                    directoryPath += "/My Custom Downloads";

                    String path = directoryPath + "/$fileName";
                    path = path.substring(0, path.lastIndexOf("."));
                    print("Path:${path}");
                    if(Directory(path).existsSync()) {
                      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("File Already Extracted")));
                    }
                    else {
                      if(zipFile != null) {
                        extractZipFile();
                      }
                      else {
                        ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("No File Selected")));
                      }
                    }
                  }
                },),
                getButton("Open Webview", () async {
                  if(textEditingController.text.isEmpty) {
                    ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("Please Enter a Url")));
                    return;
                  }
                  String fileName = textEditingController.text.substring(textEditingController.text.lastIndexOf("/") + 1);

                  Directory? directory = await getExternalStorageDirectory();
                  if(directory != null) {
                    String directoryPath = directory.path;
                    directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
                    directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
                    directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
                    directoryPath = directoryPath.substring(0, directoryPath.lastIndexOf("/"));
                    directoryPath += "/My Custom Downloads";

                    String path = directoryPath + "/$fileName";
                    path = path.substring(0, path.lastIndexOf("."));
                    path = path + "/start.html";
                    print("Path:${path}");
                    if(File(path).existsSync()) {
                      openWebView(path);
                    }
                    else {
                      ScaffoldMessenger.of(_scaffoldKey.currentContext!).showSnackBar(SnackBar(content: Text("File start.html not found")));
                    }
                  }
                },),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget getButton(String text, Function ontap) {
    return InkWell(
      onTap: () {
        ontap();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.blue,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: TextStyle(color: Colors.white),),
      ),
    );
  }
}
