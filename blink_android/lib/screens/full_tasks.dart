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
  @override
  Widget build(BuildContext context) => BlinkCreateLayout(
    title: widget.task == null ? 'New Creator Task' : 'Edit Creator Task',
    subtitle: 'Publish a challenge with clear steps and rewards.',
    icon: Icons.task_alt_rounded,
    busy: busy,
    primaryLabel: busy ? 'Saving... $progress%' : 'Save Creator Task',
    onSubmit: _save,
    progress: progress > 0
        ? LinearProgressIndicator(value: progress / 100,
            color: BlinkColors.orange)
        : null,
    content: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      BlinkFormSection(
        heading: 'Task details',
        helper: 'Explain the challenge and choose when it should be visible.',
        children: [
          TextField(
            controller: title, maxLength: 140,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Task title'),
          ),
          const SizedBox(height: 9),
          TextField(
            controller: description, maxLength: 4000,
            minLines: 4, maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Instructions', alignLabelWithHint: true),
          ),
          const SizedBox(height: 9),
          DropdownButtonFormField<String>(
            initialValue: status, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Visibility'),
            items: ['DRAFT','PUBLISHED'].map((v) =>
              DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: busy ? null : (v) {
              if (v != null) setState(() => status = v);
            },
          ),
        ],
      ),
      const SizedBox(height: 16),
      BlinkFormSection(
        heading: 'Photos & video',
        helper: 'Attach examples so participants understand the expected work.',
        children: [
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: busy ? null : _pickImages,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text('Task photos (${pictures.length}/8)'),
          )),
          ...pictures.map((f) => ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined,
              color: BlinkColors.orange),
            title: Text(f.name, maxLines: 1,
              overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Remove image',
              icon: const Icon(Icons.close),
              onPressed: busy ? null : () =>
                setState(() => pictures.remove(f)),
            ),
          )),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: busy ? null : _pickVideo,
            icon: const Icon(Icons.video_library_outlined),
            label: Text(video?.name ??
              (widget.task?['hasVideo'] == true
                ? 'Replace task video' : 'Attach task video'),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          )),
        ],
      ),
      const SizedBox(height: 16),
      BlinkFormSection(
        heading: 'Checklist & BP rewards',
        helper: 'Each step can award 0 to 5 BP when verified.',
        children: [
          ...groups.map((g) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(child: TextFormField(
                      initialValue: g.name,
                      decoration: const InputDecoration(
                        labelText: 'Checklist name'),
                      onChanged: (v) => g.name = v,
                    )),
                    IconButton(
                      tooltip: 'Remove checklist',
                      onPressed: busy ? null :
                        () => setState(() => groups.remove(g)),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ]),
                  ...g.steps.map((step) => Padding(
                    padding: const EdgeInsets.only(top: 11),
                    child: LayoutBuilder(builder: (context, constraints) {
                      final task = TextFormField(
                        key: ObjectKey(step), initialValue: step.text,
                        decoration: const InputDecoration(
                          labelText: 'Checklist step'),
                        onChanged: (v) => step.text = v,
                      );
                      final reward = TextFormField(
                        initialValue: step.reward.toString(),
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Reward (0–5 BP)'),
                        onChanged: (v) =>
                          step.reward = double.tryParse(v) ?? 0,
                      );
                      final remove = IconButton(
                        tooltip: 'Remove step',
                        onPressed: busy ? null :
                          () => setState(() => g.steps.remove(step)),
                        icon: const Icon(Icons.remove_circle_outline),
                      );
                      if (constraints.maxWidth < 335) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(children: [Expanded(child: task), remove]),
                            const SizedBox(height: 8),
                            reward,
                          ],
                        );
                      }
                      return Row(children: [
                        Expanded(flex: 4, child: task),
                        const SizedBox(width: 8),
                        Expanded(flex: 2, child: reward),
                        remove,
                      ]);
                    }),
                  )),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: busy || g.steps.length >= 30 ? null :
                      () => setState(() => g.steps.add(_Step('', '', 0))),
                    icon: const Icon(Icons.add),
                    label: const Text('Add step'),
                  ),
                ],
              ),
            ),
          )),
          OutlinedButton.icon(
            onPressed: busy || groups.length >= 12 ? null :
              () => setState(() => groups.add(
                _Group('', 'New Checklist', [_Step('', '', 0)]))),
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add Checklist'),
          ),
        ],
      ),
    ]),
  );
}
