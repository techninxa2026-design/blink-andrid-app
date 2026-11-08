import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import '../widgets/blink_motion.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../core/blink_auth_api.dart';
import '../core/live_api.dart';
import '../core/task_upload_api.dart';
import '../core/theme.dart';

class FullTaskDetail extends StatefulWidget {
  const FullTaskDetail({super.key,required this.taskId});
  final String taskId;
  @override State<FullTaskDetail> createState()=>_FullTaskDetailState();
}
class _FullTaskDetailState extends State<FullTaskDetail> {
  Map<String,dynamic> task={},saved={};
  Set<String> selected={};
  String myId='',error='';
  bool loading=true,busy=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{
      final t=obj(await LiveApi.call('GET','/creator-tasks/'+Uri.encodeComponent(widget.taskId)));
      final user=await BlinkAuthApi.cachedUser();
      final userId=field(user,'id');
      Map<String,dynamic> my={};
      if(userId!=field(t,'creatorId')){
        try{my=obj(await LiveApi.call('GET','/task-participations/'+
          Uri.encodeComponent(widget.taskId)+'/me'));}catch(_){}
      }
      if(mounted)setState((){task=t;saved=my;myId=userId;error='';loading=false;
        selected=arr(my['checkedItemIds']).map((e)=>e.toString()).toSet();});
    }catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _check(String id,bool value)async{
    if(busy)return;
    final next={...selected};
    if(value){next.add(id);}else{next.remove(id);}
    setState((){busy=true;selected=next;});
    try{
      await LiveApi.call('PUT','/task-participations/'+Uri.encodeComponent(widget.taskId)+
        '/checklist',{'checkedItemIds':next.toList()});
      await _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _submit()async{
    final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Submit for verification?'),
      content:const Text('Once submitted, your saved evidence is locked. The creator reviews each response before verified BP is credited.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Submit'))]));
    if(confirmed!=true)return;
    try{
      await LiveApi.call('POST','/task-participations/'+Uri.encodeComponent(widget.taskId)+'/submit');
      await _load();
      if(mounted)liveNotice(context,'Submitted for creator verification.');
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context){
    final owner=myId.isNotEmpty&&field(task,'creatorId')==myId;
    final locked=saved.isNotEmpty&&field(saved,'status','DRAFT')!='DRAFT';
    final steps=arr(saved['steps']).map(obj).toList();
    final totalSteps = arr(task['checklists']).fold<int>(0,
      (count, group) => count + arr(obj(group)['items']).length);
    final doneSteps = selected.length.clamp(0, totalSteps);
    final progress = totalSteps == 0 ? 0.0 : doneSteps / totalSteps;
    return Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('Creator Task')),
      body:loading?const Center(child:CircularProgressIndicator(color:BlinkColors.orange))
        :error.isNotEmpty?liveError(error,_load)
        :RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(16),children:[
          BlinkFeatureHero(
            eyebrow:'VERIFIED CREATOR CHALLENGE',
            title:field(task,'title'),
            subtitle:field(task,'description'),
            icon:Icons.task_alt_rounded,
            mood:BlinkMood.studio,
            margin:const EdgeInsets.fromLTRB(0,0,0,16),
          ),
          Wrap(spacing:8,runSpacing:8,children:[
            BlinkInfoPill(field(task['creator'],'name','Creator'),
              icon:Icons.person_outline_rounded),
            BlinkInfoPill('${field(task,'rewardBp','0')} BP',
              icon:Icons.stars_rounded,highlight:true),
          ]),
          const SizedBox(height:16),
          if(field(task,'videoUrl').isNotEmpty)Padding(padding:const EdgeInsets.only(top:14),
            child:SizedBox(height:240,child:TaskMediaVideo(
              url:LiveApi.root+field(task,'videoUrl')))),
          if(arr(task['images']).isNotEmpty)SizedBox(height:136,
            child:ListView(scrollDirection:Axis.horizontal,children:[
              ...arr(task['images']).map((image)=>Padding(padding:const EdgeInsets.all(4),
                child:Image.network(LiveApi.root+'/task-media/images/'+
                  Uri.encodeComponent(field(image,'id')),width:130,fit:BoxFit.cover,
                  errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)))),
            ])),
          if(locked)BlinkProListCard(
            title:'Participation: '+field(saved,'status'),
            eyebrow:'YOUR SUBMISSION',
            icon:Icons.verified_user_outlined,
            badges:[BlinkInfoPill('${field(saved,'earnedBp','0')} BP approved',
              icon:Icons.stars_rounded,highlight:true)],
          ),
          const SizedBox(height: 12),
          BlinkProCard(
            mood: BlinkMood.rewards,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.fact_check_outlined,
                    size: 20, color: Color(0xFFB1721D)),
                  const SizedBox(width: 9),
                  const Expanded(child: Text('Your checklist progress',
                    style: TextStyle(fontWeight: FontWeight.w900))),
                  Text(doneSteps.toString() + ' / ' +
                    totalSteps.toString(),
                    style: const TextStyle(
                      color: Color(0xFFB1721D),
                      fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 13),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: progress),
                  duration: BlinkMotion.duration(context, ms: 460),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      color: BlinkColors.orange,
                      backgroundColor: BlinkColors.orangeSoft)),
                ),
                const SizedBox(height: 9),
                Text(locked
                  ? 'Submission locked for verification'
                  : 'Complete the required steps before submitting.',
                  style: const TextStyle(fontSize: 11.5,
                    color: BlinkColors.muted)),
              ],
            ),
          ),
          const BlinkSectionBand(
            eyebrow: 'STEP BY STEP',
            title: 'Challenge checklist',
            subtitle: 'Follow the real requirements and attach evidence',
            mood: BlinkMood.rewards,
            icon: Icons.checklist_rounded,
            padding: EdgeInsets.fromLTRB(1, 8, 1, 15)),
          ...arr(task['checklists']).map((rawGroup){
            final group=obj(rawGroup);
            return Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Padding(padding:const EdgeInsets.only(top:14,bottom:6),
                child:Text(field(group,'name'),style:const TextStyle(fontWeight:FontWeight.w800))),
              ...arr(group['items']).map((rawItem){
                final item=obj(rawItem),id=field(item,'id');
                final matches=steps.where((s)=>field(s,'checklistItemId')==id).toList();
                final step=matches.isEmpty?<String,dynamic>{}:matches.first;
                return BlinkProCard(padding:const EdgeInsets.fromLTRB(8,8,8,3),
                  child:Column(children:[
                  CheckboxListTile(
                    activeColor:BlinkColors.orange,
                    title:Text(field(item,'text'),
                      style:const TextStyle(fontWeight:FontWeight.w800)),
                    subtitle:Wrap(spacing:6,runSpacing:6,children:[
                      BlinkInfoPill('${field(item,'rewardBp','0')} BP',
                        icon:Icons.stars_rounded,highlight:true),
                      BlinkInfoPill(step.isEmpty?'No evidence saved'
                        :field(step,'reviewStatus'),icon:Icons.checklist_rtl_outlined),
                    ]),
                    value:selected.contains(id),onChanged:owner||locked||busy?null:
                      (v)=>_check(id,v==true)),
                  if(!owner)Align(alignment:Alignment.centerRight,
                    child:Padding(padding:const EdgeInsets.only(right:12,bottom:8),
                      child:OutlinedButton.icon(onPressed:locked?null:()=>Navigator.push<bool>(
                        context,MaterialPageRoute(builder:(_)=>FullTaskEvidenceEditor(
                          taskId:widget.taskId,item:item,step:step))).then((changed){
                            if(changed==true)_load();
                          }),
                        icon:const Icon(Icons.add_photo_alternate_outlined),
                        label:Text(step.isEmpty?'Add evidence':'Edit evidence')))),
                  if(locked&&field(step,'reviewNote').isNotEmpty)
                    Padding(padding:const EdgeInsets.all(10),
                      child:Text('Creator note: '+field(step,'reviewNote'))),
                ]));
              }),
            ]);
          }),
          if(!owner&&!locked)Padding(padding:const EdgeInsets.only(top:15),
            child:FilledButton.icon(onPressed:busy?null:_submit,
              icon:const Icon(Icons.fact_check_outlined),
              label:const Text('Submit responses for verification'))),
        ])));
  }
}

class FullTaskEvidenceEditor extends StatefulWidget {
  const FullTaskEvidenceEditor({super.key,required this.taskId,required this.item,required this.step});
  final String taskId;
  final Map<String,dynamic> item,step;
  @override State<FullTaskEvidenceEditor> createState()=>_EvidenceState();
}
class _EvidenceState extends State<FullTaskEvidenceEditor>{
  late final explanation=TextEditingController(text:field(widget.step,'explanation'));
  late final List<String> oldImages=arr(widget.step['images']).map((i)=>field(i,'id')).toList();
  List<XFile> pictures=[];XFile? video;
  bool busy=false;int progress=0;
  @override void dispose(){explanation.dispose();super.dispose();}
  Future<void> _photos()async{
    try{final selected=await ImagePicker().pickMultiImage(imageQuality:82);
      if(mounted)setState(()=>pictures=selected.take(8-oldImages.length).toList());}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _video()async{
    try{final picked=await ImagePicker().pickVideo(source:ImageSource.gallery);
      if(mounted)setState(()=>video=picked);}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _save()async{
    if(busy)return;setState(()=>busy=true);
    try{
      final ids=<String>[...oldImages];
      for(final photo in pictures){
        ids.add(await BlinkTaskUploads.uploadImage(File(photo.path),creator:false));
      }
      if(ids.length>8)throw const LiveApiError('Maximum 8 photos per task item.');
      String? videoId;
      if(video!=null)videoId=await BlinkTaskUploads.uploadVideo(File(video!.path),
        creator:false,onProgress:(p){if(mounted)setState(()=>progress=p);});
      await LiveApi.call('PUT','/task-participations/'+Uri.encodeComponent(widget.taskId)+
        '/steps/'+Uri.encodeComponent(field(widget.item,'id')),{
          'explanation':explanation.text.trim(),'imageIds':ids,
          if(videoId!=null)'videoUploadId':videoId,
        });
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override
  Widget build(BuildContext context) => BlinkCreateLayout(
    title: 'Checklist Evidence',
    subtitle: 'Show what you completed so the creator can verify your work.',
    icon: Icons.fact_check_outlined,
    busy: busy,
    primaryLabel: busy ? 'Saving... $progress%' : 'Save evidence',
    onSubmit: _save,
    progress: progress > 0
      ? LinearProgressIndicator(value: progress / 100, color: BlinkColors.orange)
      : null,
    content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BlinkFormSection(
        heading: 'Your checklist step',
        helper: 'Your submission is reviewed before rewards are granted.',
        children: [
          Text(field(widget.item, 'text'),
            style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Potential reward: ${field(widget.item,'rewardBp')} BP',
            style: const TextStyle(
              color: BlinkColors.orangeDark, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          TextField(
            controller: explanation, maxLength: 6000,
            minLines: 4, maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Explain what you completed',
              alignLabelWithHint: true),
          ),
        ],
      ),
      const SizedBox(height: 16),
      BlinkFormSection(
        heading: 'Proof & attachments',
        helper: 'You can provide up to 8 photos and one video.',
        children: [
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: busy ? null : _photos,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text('Evidence photos (${oldImages.length + pictures.length}/8)'),
          )),
          ...oldImages.map((id) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined, color: BlinkColors.orange),
            title: Text('Saved evidence photo', maxLines: 1,
              overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Remove saved photo',
              onPressed: busy ? null :
                () => setState(() => oldImages.remove(id)),
              icon: const Icon(Icons.close),
            ),
          )),
          ...pictures.map((picture) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined, color: BlinkColors.orange),
            title: Text(picture.name, maxLines: 1,
              overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Remove selected photo',
              onPressed: busy ? null :
                () => setState(() => pictures.remove(picture)),
              icon: const Icon(Icons.close),
            ),
          )),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: busy ? null : _video,
            icon: const Icon(Icons.video_library_outlined),
            label: Text(video?.name ??
                (field(widget.step,'videoUploadId').isEmpty
                  ? 'Attach evidence video' : 'Replace evidence video'),
              overflow: TextOverflow.ellipsis, maxLines: 1),
          )),
        ],
      ),
    ]),
  );
}
class TaskMediaVideo extends StatefulWidget{
  const TaskMediaVideo({super.key,required this.url});
  final String url;
  @override State<TaskMediaVideo> createState()=>_TaskVideoState();
}
class _TaskVideoState extends State<TaskMediaVideo>{
  VideoPlayerController? player;String? error;
  @override void initState(){super.initState();_init();}
  Future<void> _init()async{
    final current=VideoPlayerController.networkUrl(Uri.parse(widget.url));
    player=current;
    try{await current.initialize();if(mounted)setState((){});}
    catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  @override void dispose(){player?.dispose();super.dispose();}
  @override Widget build(BuildContext context){
    final p=player;
    if(error!=null)return Center(child:Text('Video unavailable: $error'));
    if(p==null||!p.value.isInitialized)
      return const Center(child:CircularProgressIndicator(color:BlinkColors.orange));
    return Center(child:AspectRatio(aspectRatio:p.value.aspectRatio,
      child:Stack(alignment:Alignment.center,children:[
        VideoPlayer(p),
        IconButton.filled(onPressed:()async{
          if(p.value.isPlaying){await p.pause();}else{await p.play();}
          if(mounted)setState((){});
        },icon:Icon(p.value.isPlaying?Icons.pause:Icons.play_arrow)),
      ])));
  }
}
