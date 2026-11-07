import 'dart:io';
import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import 'package:image_picker/image_picker.dart';
import '../core/live_api.dart';
import '../core/task_upload_api.dart';
import '../core/theme.dart';
import 'task_participation.dart';
import 'task_reviews.dart';

class FullTasksScreen extends StatefulWidget {
  const FullTasksScreen({super.key});
  @override State<FullTasksScreen> createState()=>_TasksState();
}
class _TasksState extends State<FullTasksScreen> {
  final query=TextEditingController();List<dynamic> tasks=[];String error='';bool loading=true;int page=1;
  @override void initState(){super.initState();_load();}
  @override void dispose(){query.dispose();super.dispose();}
  Future<void> _load()async{
    setState((){loading=true;error='';});
    try{
      final params=<String,String>{'page':'$page'};
      if(query.text.trim().isNotEmpty)params['q']=query.text.trim();
      final rows=arr(await LiveApi.call('GET','/creator-tasks?'+Uri(queryParameters:params).query));
      if(mounted)setState((){tasks=rows;loading=false;});
    }catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('Blink Tasks'),
    actions:[IconButton(icon:const Icon(Icons.dashboard_outlined),tooltip:'Creator Studio',
      onPressed:()=>Navigator.push<void>(context,MaterialPageRoute(
        builder:(_)=>const FullCreatorDashboard())))]),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(controller:query,
        onSubmitted:(_){page=1;_load();},
        decoration:InputDecoration(prefixIcon:const Icon(Icons.search),hintText:'Search Creator Tasks',
          suffixIcon:IconButton(icon:const Icon(Icons.arrow_forward),
            onPressed:(){page=1;_load();})))),
      Expanded(child:loading?const Center(child:CircularProgressIndicator(color:BlinkColors.orange))
        :error.isNotEmpty?liveError(error,_load)
        :RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
          if(tasks.isEmpty)const ListTile(title:Text('No published tasks found.')),
          ...tasks.map((raw){final t=obj(raw);return Card(child:ListTile(
            leading:const CircleAvatar(backgroundColor:BlinkColors.orangeSoft,
              child:Icon(Icons.task_alt,color:BlinkColors.orange)),
            title:Text(field(t,'title')),
            subtitle:Text(field(t['creator'],'name')+' · '+field(t,'rewardBp')+
              ' BP\n'+field(t,'description'),maxLines:3,overflow:TextOverflow.ellipsis),
            onTap:()=>Navigator.push<void>(context,MaterialPageRoute(
              builder:(_)=>FullTaskDetail(taskId:field(t,'id'))))));}),
          Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            TextButton(onPressed:page>1?(){page--;_load();}:null,child:const Text('Previous')),
            Text('Page $page'),
            TextButton(onPressed:tasks.length==24?(){page++;_load();}:null,child:const Text('Next')),
          ]),
        ]))),
    ]));
}

class FullCreatorDashboard extends StatefulWidget{
  const FullCreatorDashboard({super.key});
  @override State<FullCreatorDashboard> createState()=>_CreatorState();
}
class _CreatorState extends State<FullCreatorDashboard>{
  List<dynamic> tasks=[];String error='';bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=arr(await LiveApi.call('GET','/creator-tasks/mine'));
      if(mounted)setState((){tasks=rows;error='';loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _edit([Map<String,dynamic>? task])async{
    final changed=await Navigator.push<bool>(context,
      MaterialPageRoute(builder:(_)=>FullCreatorEditor(task:task)));
    if(changed==true)_load();
  }
  Future<void> _delete(String id)async{
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Delete Creator Task?'),content:const Text('This action is permanent.'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Delete'))]));
    if(yes!=true)return;
    try{await LiveApi.call('DELETE','/creator-tasks/'+Uri.encodeComponent(id));_load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('Creator Studio'),
    actions:[IconButton(onPressed:()=>_edit(),icon:const Icon(Icons.add_circle_outline))]),
    body:loading?const Center(child:CircularProgressIndicator())
      :error.isNotEmpty?Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
        Padding(padding:const EdgeInsets.all(12),child:Text(error,textAlign:TextAlign.center)),
        OutlinedButton(onPressed:()=>Navigator.pushNamed(context,'/business'),
          child:const Text('Activate Professional Business Profile')),
        TextButton(onPressed:_load,child:const Text('Retry')),
      ])):RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
        const ListTile(title:Text('My Creator Tasks'),subtitle:Text('Publish and verify BP rewards.')),
        if(tasks.isEmpty)const ListTile(title:Text('No tasks yet.')),
        ...tasks.map((raw){final t=obj(raw),id=field(t,'id');
          return Card(child:Column(children:[
            ListTile(title:Text(field(t,'title')),subtitle:Text(field(t,'status')+
              ' · '+field(t,'rewardBp')+' BP'),onTap:()=>_edit(t)),
            Wrap(spacing:6,children:[
              TextButton.icon(onPressed:()=>_edit(t),icon:const Icon(Icons.edit_outlined),label:const Text('Edit')),
              TextButton.icon(onPressed:()=>Navigator.push<void>(context,MaterialPageRoute(
                builder:(_)=>FullTaskReviews(taskId:id))),
                icon:const Icon(Icons.fact_check_outlined),label:const Text('Review')),
              TextButton.icon(onPressed:()=>_delete(id),icon:const Icon(Icons.delete_outline),
                label:const Text('Delete')),
            ]),
          ]));
        }),
      ])));
}
class _Step {
  _Step(this.id,this.text,this.reward);
  String id,text;double reward;
}
class _Group {
  _Group(this.id,this.name,this.steps);
  String id,name;List<_Step> steps;
}
class FullCreatorEditor extends StatefulWidget{
  const FullCreatorEditor({super.key,this.task});
  final Map<String,dynamic>? task;
  @override State<FullCreatorEditor> createState()=>_EditorState();
}
class _EditorState extends State<FullCreatorEditor>{
  late final title=TextEditingController(text:field(widget.task,'title'));
  late final description=TextEditingController(text:field(widget.task,'description'));
  late String status=field(widget.task,'status','DRAFT');
  late final List<_Group> groups=(){
    final raw=arr(widget.task?['checklists']);
    if(raw.isEmpty)return <_Group>[_Group('','Main Checklist',[_Step('','',0)])];
    return raw.map((g)=>_Group(field(g,'id'),field(g,'name'),
      arr(obj(g)['items']).map((s)=>_Step(field(s,'id'),field(s,'text'),
        double.tryParse(field(s,'rewardBp','0'))??0)).toList())).toList();
  }();
  List<XFile> pictures=[];XFile? video;int progress=0;bool busy=false;
  @override void dispose(){title.dispose();description.dispose();super.dispose();}
  Future<void> _pickImages()async{
    try{final selected=await ImagePicker().pickMultiImage(imageQuality:80,maxWidth:1600);
      if(mounted)setState(()=>pictures=selected.take(8).toList());}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _pickVideo()async{
    try{final selected=await ImagePicker().pickVideo(source:ImageSource.gallery);
      if(mounted)setState(()=>video=selected);}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _save()async{
    if(busy)return;setState(()=>busy=true);
    try{
      final imageIds=<String>[];
      if(pictures.isEmpty)imageIds.addAll(arr(widget.task?['images']).map((x)=>field(x,'id')));
      else for(final file in pictures){
        imageIds.add(await BlinkTaskUploads.uploadImage(File(file.path),creator:true));
      }
      String? videoId;
      if(video!=null)videoId=await BlinkTaskUploads.uploadVideo(File(video!.path),
        creator:true,onProgress:(p){if(mounted)setState(()=>progress=p);});
      final id=field(widget.task,'id');
      await LiveApi.call(id.isEmpty?'POST':'PUT',
        id.isEmpty?'/creator-tasks':'/creator-tasks/'+Uri.encodeComponent(id),{
          'title':title.text.trim(),'description':description.text.trim(),
          'status':status,'imageIds':imageIds,
          if(videoId!=null)'videoUploadId':videoId,
          'checklists':groups.map((g)=><String,dynamic>{
            if(g.id.isNotEmpty)'id':g.id,'name':g.name.trim(),
            'items':g.steps.map((s)=><String,dynamic>{
              if(s.id.isNotEmpty)'id':s.id,'text':s.text.trim(),'rewardBp':s.reward,
            }).toList(),
          }).toList(),
        });
      if(mounted)Navigator.pop(context,true);
    }catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.task==null?'New Creator Task':'Edit Creator Task')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      TextField(controller:title,maxLength:140,decoration:const InputDecoration(labelText:'Title')),
      TextField(controller:description,maxLength:4000,minLines:4,maxLines:8,
        decoration:const InputDecoration(labelText:'Instructions')),
      DropdownButtonFormField<String>(initialValue:status,
        items:['DRAFT','PUBLISHED'].map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),
        onChanged:busy?null:(v){if(v!=null)setState(()=>status=v);}),
      OutlinedButton.icon(onPressed:busy?null:_pickImages,
        icon:const Icon(Icons.add_photo_alternate_outlined),
        label:Text('Task images ('+pictures.length.toString()+'/8)')),
      ...pictures.map((f)=>ListTile(title:Text(f.name),
        trailing:IconButton(icon:const Icon(Icons.close),
          onPressed:()=>setState(()=>pictures.remove(f))))),
      OutlinedButton.icon(onPressed:busy?null:_pickVideo,
        icon:const Icon(Icons.video_library_outlined),
        label:Text(video?.name??(widget.task?['hasVideo']==true?'Replace video':'Attach video to publish'))),
      if(progress>0)LinearProgressIndicator(value:progress/100,color:BlinkColors.orange),
      const Divider(height:30),
      Text('Named Checklists & BP',style:Theme.of(context).textTheme.titleLarge),
      ...groups.map((g)=>Card(child:Padding(padding:const EdgeInsets.all(10),child:Column(children:[
        Row(children:[Expanded(child:TextFormField(initialValue:g.name,
          decoration:const InputDecoration(labelText:'Checklist name'),onChanged:(v)=>g.name=v)),
          IconButton(onPressed:busy?null:()=>setState(()=>groups.remove(g)),
            icon:const Icon(Icons.delete_outline))]),
        ...g.steps.map((step)=>Padding(
          padding:const EdgeInsets.only(top:8),
          child:LayoutBuilder(builder:(context,constraints) {
            final task = TextFormField(key:ObjectKey(step),initialValue:step.text,
              decoration:const InputDecoration(labelText:'Checklist task'),
              onChanged:(v)=>step.text=v);
            final reward = TextFormField(initialValue:step.reward.toString(),
              keyboardType:const TextInputType.numberWithOptions(decimal:true),
              decoration:const InputDecoration(labelText:'BP 0–5'),
              onChanged:(v)=>step.reward=double.tryParse(v)??0);
            final remove = IconButton(
              tooltip:'Remove checklist step',
              onPressed:busy?null:()=>setState(()=>g.steps.remove(step)),
              icon:const Icon(Icons.remove_circle_outline));
            if (constraints.maxWidth < 330) {
              return Column(children:[
                Row(children:[Expanded(child:task),remove]),
                const SizedBox(height:8),
                reward,
              ]);
            }
            return Row(children:[
              Expanded(flex:4,child:task),
              const SizedBox(width:8),
              Expanded(flex:2,child:reward),
              remove,
            ]);
          }),
        )),
        TextButton.icon(onPressed:busy||g.steps.length>=30?null:()=>
          setState(()=>g.steps.add(_Step('','',0))),icon:const Icon(Icons.add),
          label:const Text('Add task step')),
      ])))),
      OutlinedButton.icon(onPressed:busy||groups.length>=12?null:()=>
        setState(()=>groups.add(_Group('','New Checklist',[_Step('','',0)]))),
        icon:const Icon(Icons.playlist_add),label:const Text('Add Checklist')),
      const SizedBox(height:16),
      FilledButton.icon(onPressed:busy?null:_save,icon:const Icon(Icons.publish_outlined),
        label:Text(busy?'Uploading/saving... $progress%':'Save Creator Task')),
    ]));
}
