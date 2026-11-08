import 'dart:async';
import 'dart:io';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import '../widgets/blink_motion.dart';
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
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const BlinkBrandedTitle('Blink Voice Message')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BlinkFeatureHero(
              eyebrow: 'SAY IT YOUR WAY',
              title: 'Your voice matters.',
              subtitle: 'Record and send a warm, personal message.',
              icon: Icons.graphic_eq_rounded,
              mood: BlinkMood.community,
              margin: EdgeInsets.fromLTRB(0, 0, 0, 24)),
            Center(child: AnimatedScale(
              scale: recording && !BlinkMotion.reduced(context) ? 1.085 : 1,
              duration: BlinkMotion.duration(context, ms: 240),
              curve: Curves.easeOutBack,
              child: AnimatedContainer(
                duration: BlinkMotion.duration(context, ms: 270),
                width: 132, height: 132,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: recording
                    ? [const Color(0xFFE52D65), const Color(0xFFFF9171)]
                    : [const Color(0xFFFFE7D9), const Color(0xFFFFD2BA)]),
                  borderRadius: BorderRadius.circular(45),
                  border: Border.all(
                    color: recording
                      ? const Color(0xFFFFB5C8)
                      : const Color(0xFFFFC4A0), width: 2)),
                child: Icon(recording
                  ? Icons.graphic_eq_rounded : Icons.mic_none_rounded,
                  color: recording ? Colors.white : BlinkColors.orangeDark,
                  size: 57),
              ),
            )),
            const SizedBox(height: 24),
            AnimatedSwitcher(
              duration: BlinkMotion.duration(context, ms: 220),
              child: Text(recording ? 'Recording your voice'
                  : file != null ? 'Ready to share' : 'Start recording',
                key: ValueKey(recording.toString() + (file != null).toString()),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22,
                  color: BlinkColors.ink, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 10),
            Center(child: Text(
              (seconds ~/ 60).toString().padLeft(2, '0') + ':' +
                (seconds % 60).toString().padLeft(2, '0'),
              style: const TextStyle(color: BlinkColors.orangeDark,
                fontSize: 39, fontWeight: FontWeight.w900,
                fontFeatures: [FontFeature.tabularFigures()]))),
            const SizedBox(height: 15),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: (seconds / 120).clamp(0, 1)),
              duration: BlinkMotion.duration(context, ms: 270),
              builder: (_, value, __) => ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: value,
                  color: recording
                    ? const Color(0xFFE52D65) : BlinkColors.orange,
                  backgroundColor: BlinkColors.orangeSoft,
                  minHeight: 8)),
            ),
            const SizedBox(height: 9),
            const Center(child: Text('Up to 2 minutes · Private audio message',
              style: TextStyle(color: BlinkColors.muted, fontSize: 11.5))),
            if (error.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text(error, textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFCB3359))),
            ],
            const SizedBox(height: 23),
            if (!recording && file == null)
              FilledButton.icon(
                onPressed: busy ? null : _start,
                icon: const Icon(Icons.fiber_manual_record_rounded),
                label: const Text('Start recording')),
            if (recording)
              FilledButton.icon(
                onPressed: busy ? null : _stop,
                icon: const Icon(Icons.stop_circle_rounded),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFD52D5F)),
                label: const Text('Finish recording')),
            if (file != null) ...[
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, file),
                icon: const Icon(Icons.send_rounded),
                label: const Text('Send voice message')),
              const SizedBox(height: 9),
              OutlinedButton.icon(
                onPressed: () async {
                  final old = file;
                  setState(() { file = null; seconds = 0; });
                  if (old != null) {
                    await old.delete().catchError((_) => old);
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Record again')),
            ],
          ],
        ),
      ),
    ),
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
