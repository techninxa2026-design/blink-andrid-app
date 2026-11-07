import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import '../core/live_api.dart';
import '../core/theme.dart';

class BlinkVoiceRecordScreen extends StatefulWidget{
  const BlinkVoiceRecordScreen({super.key});
  @override State<BlinkVoiceRecordScreen> createState()=>_RecorderState();
}
class _RecorderState extends State<BlinkVoiceRecordScreen>{
  final recorder=AudioRecorder();
  File? file;Timer? timer;int seconds=0;
  bool recording=false,busy=false;String error='';
  @override void dispose(){timer?.cancel();recorder.dispose();super.dispose();}
  Future<void> _start()async{
    if(busy||recording)return;setState(()=>busy=true);
    try{
      if(!await recorder.hasPermission())throw const LiveApiError('Enable microphone permission in Android Settings.');
      final path=Directory.systemTemp.path+'/blink_voice_'+DateTime.now().microsecondsSinceEpoch.toString()+'.m4a';
      await recorder.start(const RecordConfig(encoder:AudioEncoder.aacLc,
        bitRate:128000,sampleRate:44100),path:path);
      if(mounted)setState((){recording=true;seconds=0;file=null;error='';});
      timer=Timer.periodic(const Duration(seconds:1),(t){
        if(!mounted){t.cancel();return;}
        setState(()=>seconds++);
        if(seconds>=120)_stop();
      });
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _stop()async{
    if(!recording||busy)return;timer?.cancel();setState(()=>busy=true);
    try{
      final path=await recorder.stop();
      if(path==null)throw const LiveApiError('Voice recorder returned no file.');
      final saved=File(path);
      if(await saved.length()==0)throw const LiveApiError('Voice message is empty.');
      if(mounted)setState((){recording=false;file=saved;});
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const BlinkBrandedTitle('Blink Voice Message')),
    body:Center(child:Padding(padding:const EdgeInsets.all(24),
      child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
        CircleAvatar(radius:52,backgroundColor:BlinkColors.orangeSoft,
          child:Icon(recording?Icons.mic:Icons.mic_none,color:BlinkColors.orange,size:52)),
        const SizedBox(height:16),
        Text(recording?'Recording...':'Voice Message',
          style:Theme.of(context).textTheme.titleLarge),
        Text('Duration: '+(seconds~/60).toString()+':'+
          (seconds%60).toString().padLeft(2,'0')),
        const Text('Maximum 2 minutes'),
        if(error.isNotEmpty)Padding(padding:const EdgeInsets.all(12),
          child:Text(error,style:const TextStyle(color:Colors.red))),
        const SizedBox(height:16),
        if(!recording&&file==null)FilledButton.icon(onPressed:busy?null:_start,
          icon:const Icon(Icons.fiber_manual_record),label:const Text('Start recording')),
        if(recording)FilledButton.icon(onPressed:busy?null:_stop,
          icon:const Icon(Icons.stop_circle),label:const Text('Stop')),
        if(file!=null)...[
          FilledButton.icon(onPressed:()=>Navigator.pop(context,file),
            icon:const Icon(Icons.send),label:const Text('Send voice message')),
          OutlinedButton(onPressed:()async{
            final old=file;setState(()=>file=null);
            if(old!=null)await old.delete().catchError((_){return old;});
          },child:const Text('Discard and re-record')),
        ],
      ]),
    )),
  );
}

class BlinkVoiceBubble extends StatefulWidget{
  const BlinkVoiceBubble({super.key,required this.messageId,required this.bearer});
  final String messageId,bearer;
  @override State<BlinkVoiceBubble> createState()=>_BubbleState();
}
class _BubbleState extends State<BlinkVoiceBubble>{
  final player=AudioPlayer();
  File? cached;bool playing=false,loading=false;String error='';
  StreamSubscription<void>? completed;
  @override void initState(){
    super.initState();
    completed=player.onPlayerComplete.listen((_){
      if(mounted)setState(()=>playing=false);
    });
  }
  @override void dispose(){
    completed?.cancel();player.dispose();
    cached?.delete().ignore();super.dispose();
  }
  Future<void> _play()async{
    if(loading)return;
    if(playing){
      try{await player.pause();if(mounted)setState(()=>playing=false);}
      catch(e){if(mounted)setState(()=>error=e.toString());}
      return;
    }
    setState(()=>loading=true);
    try{
      File? file=cached;
      if(file==null||!await file.exists()){
        final response=await http.get(
          Uri.parse(LiveApi.root+'/inbox/media/'+Uri.encodeComponent(widget.messageId)),
          headers:{'Authorization':'Bearer '+widget.bearer},
        ).timeout(const Duration(seconds:45));
        if(response.statusCode!=200)throw LiveApiError(
          'Voice unavailable: HTTP '+response.statusCode.toString());
        file=File(Directory.systemTemp.path+'/blink_voice_play_'+
          DateTime.now().microsecondsSinceEpoch.toString()+'.m4a');
        await file.writeAsBytes(response.bodyBytes,flush:true);
        cached=file;
      }
      await player.play(DeviceFileSource(file.path));
      if(mounted)setState((){playing=true;error='';});
    }catch(e){if(mounted)setState(()=>error=e.toString());}
    finally{if(mounted)setState(()=>loading=false);}
  }
  @override Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,children:[
      TextButton.icon(onPressed:loading?null:_play,
        icon:Icon(loading?Icons.hourglass_empty:playing?Icons.pause_circle:Icons.play_circle,
          color:BlinkColors.orange),
        label:Text(loading?'Loading audio...':playing?'Pause voice':'Play voice note')),
      if(error.isNotEmpty)Text(error,style:const TextStyle(fontSize:11,color:Colors.red)),
    ]);
}
