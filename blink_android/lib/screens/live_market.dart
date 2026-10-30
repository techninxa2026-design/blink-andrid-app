import 'package:flutter/material.dart';
import '../core/live_api.dart';
import '../core/theme.dart';

class LiveExchangeScreen extends StatefulWidget {
  const LiveExchangeScreen({super.key});
  @override State<LiveExchangeScreen> createState() => _ExchangeState();
}
class _ExchangeState extends State<LiveExchangeScreen> {
  List<dynamic> items=[];String? error;bool loading=true;String query='';int page=1,pages=1;
  @override void initState(){super.initState();_load();}
  Future<void> _load({int? next})async{
    if(next!=null)page=next;
    try{final response=obj(await LiveApi.call('GET','/Exchange?page=$page&search=${Uri.encodeQueryComponent(query)}'));
      if(mounted)setState((){items=arr(response['items']);pages=int.tryParse(field(response,'pages','1'))??1;loading=false;error=null;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _create()async{
    final title=TextEditingController(),description=TextEditingController();String kind='OFFER';
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,refresh)=>AlertDialog(
      title:const Text('Publish Exchange Post'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Title (6–140 characters)')),
        TextField(controller:description,maxLines:5,decoration:const InputDecoration(labelText:'Description (20+ characters)')),
        DropdownButton<String>(value:kind,isExpanded:true,items:['OFFER','REQUEST','ADVICE','COLLABORATION']
          .map((k)=>DropdownMenuItem(value:k,child:Text(k))).toList(),onChanged:(v){if(v!=null)refresh(()=>kind=v);}),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,{'title':title.text.trim(),'description':description.text.trim(),'kind':kind}),
          child:const Text('Publish'))],
    )));
    title.dispose();description.dispose();if(data==null)return;
    try{await LiveApi.call('POST','/Exchange',data);await _load(next:1);}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Blink Exchange'),actions:[
      IconButton(icon:const Icon(Icons.add_circle_outline),tooltip:'Publish',onPressed:_create)]),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:TextField(
        decoration:InputDecoration(hintText:'Search services and requests',
          suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:()=>_load(next:1))),
        onChanged:(v)=>query=v,onSubmitted:(_)=>_load(next:1))),
      Expanded(child:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
        RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
          if(items.isEmpty)const ListTile(title:Text('No Exchange posts available.')),
          ...items.map((entry){final item=obj(entry);return Card(child:ListTile(
            title:Text(field(item,'title')),subtitle:Text('${field(item,'kind')} · ${field(item['author'],'name')}\n${field(item,'description')}',
              maxLines:3,overflow:TextOverflow.ellipsis),
            onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LiveExchangeDetail(id:field(item,'id')))),
          ));}),
          Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            IconButton(icon:const Icon(Icons.chevron_left),onPressed:page>1?()=>_load(next:page-1):null),
            Text('Page $page / $pages'),
            IconButton(icon:const Icon(Icons.chevron_right),onPressed:page<pages?()=>_load(next:page+1):null),
          ]),
        ]))),
    ]),
  );
}

class LiveExchangeDetail extends StatefulWidget{
  final String id;
  const LiveExchangeDetail({super.key,required this.id});
  @override State<LiveExchangeDetail> createState()=>_ExchangeDetailState();
}
class _ExchangeDetailState extends State<LiveExchangeDetail>{
  Map<String,dynamic>? post;String? error;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final value=obj(await LiveApi.call('GET','/Exchange/${Uri.encodeComponent(widget.id)}'));
      if(mounted)setState((){post=value;error=null;});}
    catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> _respond()async{
    final message=TextEditingController();
    final text=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Respond to post'),content:TextField(controller:message,maxLines:4,
        decoration:const InputDecoration(labelText:'Your message')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,message.text.trim()),child:const Text('Send'))]));
    message.dispose();if(text==null||text.isEmpty)return;
    try{await LiveApi.call('POST','/Exchange/${widget.id}/responses',{'message':text});await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context){
    final p=post??{};
    return Scaffold(appBar:AppBar(title:const Text('Exchange Details')),
      body:post==null?liveError(error,_load):ListView(padding:const EdgeInsets.all(16),children:[
        Text(field(p,'title'),style:Theme.of(context).textTheme.headlineSmall),
        Text('${field(p,'kind')} · ${field(p['author'],'name')}'),
        const SizedBox(height:16),Text(field(p,'description')),
        const Divider(),
        FilledButton.icon(onPressed:_respond,icon:const Icon(Icons.reply),label:const Text('Send Response')),
        const ListTile(title:Text('Responses',style:TextStyle(fontWeight:FontWeight.bold))),
        ...arr(p['responses']).map((r)=>ListTile(
          title:Text(field(obj(r)['author'],'name')),subtitle:Text(field(r,'message')))),
      ]));
  }
}

class LiveTasksScreen extends StatefulWidget{
  const LiveTasksScreen({super.key});
  @override State<LiveTasksScreen> createState()=>_TasksState();
}
class _TasksState extends State<LiveTasksScreen>{
  List<dynamic> tasks=[];String? error;bool loading=true;int page=1;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=arr(await LiveApi.call('GET','/creator-tasks?page=$page'));
      if(mounted)setState((){tasks=rows;error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Creator Tasks'),actions:[
    IconButton(tooltip:'Creator Dashboard',icon:const Icon(Icons.dashboard),onPressed:()=>Navigator.push(context,
      MaterialPageRoute<void>(builder:(_)=>const LiveCreatorDashboard())))]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
    RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
      if(tasks.isEmpty)const ListTile(title:Text('No published tasks available')),
      ...tasks.map((raw){final task=obj(raw);
        return Card(child:ListTile(title:Text(field(task,'title')),
          subtitle:Text('${field(task['creator'],'name')} · ${field(task,'rewardBp','0')} BP\n${field(task,'description')}',
            maxLines:3,overflow:TextOverflow.ellipsis),
          onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LiveTaskDetail(id:field(task,'id'))))));
      }),
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        TextButton(onPressed:page<=1?null:(){page--;_load();},child:const Text('Previous')),
        Text('Page $page'),
        TextButton(onPressed:tasks.length<24?null:(){page++;_load();},child:const Text('Next')),
      ]),
    ])),
  );
}

class LiveTaskDetail extends StatefulWidget{
  final String id;
  const LiveTaskDetail({super.key,required this.id});
  @override State<LiveTaskDetail> createState()=>_TaskDetailState();
}
class _TaskDetailState extends State<LiveTaskDetail>{
  Map<String,dynamic>? task;String? error;bool loading=true;bool saving=false;
  final explanation=TextEditingController();
  final selected=<String>{};Map<String,dynamic> submission={};
  @override void initState(){super.initState();_load();}
  @override void dispose(){explanation.dispose();super.dispose();}
  Future<void> _load()async{
    try{
      final t=obj(await LiveApi.call('GET','/creator-tasks/${Uri.encodeComponent(widget.id)}'));
      Map<String,dynamic> current={};
      try{current=obj(await LiveApi.call('GET','/task-participations/${Uri.encodeComponent(widget.id)}/me'));}catch(_){}
      if(!mounted)return;
      setState((){
        task=t;submission=current;explanation.text=field(current,'explanation');
        selected..clear()..addAll(arr(current['checkedItemIds']).map((e)=>e.toString()));
        loading=false;error=null;
      });
    }catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _save({bool submit=false})async{
    if(task==null||saving)return;
    setState(()=>saving=true);
    try{
      await LiveApi.call('PUT','/task-participations/${widget.id}/me',
        {'explanation':explanation.text.trim(),'checkedItemIds':selected.toList(),'imageIds':<String>[]});
      if(submit)await LiveApi.call('POST','/task-participations/${widget.id}/submit');
      if(mounted)liveNotice(context,submit?'Submission sent for verification':'Draft saved');
      await _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override Widget build(BuildContext context){
    final t=task??{};final groups=arr(t['checklists']);final locked=submission.isNotEmpty&&field(submission,'status')!='DRAFT';
    return Scaffold(appBar:AppBar(title:const Text('Task Details')),
      body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
      ListView(padding:const EdgeInsets.all(16),children:[
        Text(field(t,'title'),style:Theme.of(context).textTheme.titleLarge),
        Text('${field(t['creator'],'name')} · ${field(t,'rewardBp')} BP'),
        const SizedBox(height:12),Text(field(t,'description')),
        const Divider(),
        ...groups.map((group)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(field(group,'name'),style:Theme.of(context).textTheme.titleMedium),
          ...arr(obj(group)['items']).map((item)=>CheckboxListTile(
            title:Text(field(item,'text')),subtitle:Text('${field(item,'rewardBp')} BP'),
            value:selected.contains(field(item,'id')),onChanged:locked?null:(v){
              setState((){if(v==true){selected.add(field(item,'id'));}else{selected.remove(field(item,'id'));}});
            },
          )),
        ])),
        if(submission.isNotEmpty)Text('Participation: ${field(submission,'status','DRAFT')}'),
        TextField(controller:explanation,maxLines:4,readOnly:locked,
          decoration:const InputDecoration(labelText:'Explain your participation')),
        const SizedBox(height:12),
        if(!locked)FilledButton(onPressed:saving?null:()=>_save(),child:const Text('Save Draft')),
        if(!locked)OutlinedButton(onPressed:saving?null:()=>_save(submit:true),child:const Text('Submit for Review')),
        const SizedBox(height:12),
        const Text('Evidence media and per-step verification require the full Creator Task workflow.'),
      ]),
    );
  }
}

class LiveCreatorDashboard extends StatefulWidget{
  const LiveCreatorDashboard({super.key});
  @override State<LiveCreatorDashboard> createState()=>_CreatorState();
}
class _CreatorState extends State<LiveCreatorDashboard>{
  List<dynamic> tasks=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final r=arr(await LiveApi.call('GET','/creator-tasks/mine'));
      if(mounted)setState((){tasks=r;loading=false;error=null;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _create()async{
    final title=TextEditingController(),desc=TextEditingController(),step=TextEditingController();
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Create Creator Task'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Task title')),
        TextField(controller:desc,maxLines:3,decoration:const InputDecoration(labelText:'Description')),
        TextField(controller:step,maxLines:2,decoration:const InputDecoration(labelText:'First checklist item')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,{
          'title':title.text.trim(),'description':desc.text.trim(),
          'status':'DRAFT','checklists':[{'name':'Main Steps','items':[{'text':step.text.trim(),'rewardBp':1.0}]}],
        }),child:const Text('Save Draft'))]));
    title.dispose();desc.dispose();step.dispose();if(data==null)return;
    try{await LiveApi.call('POST','/creator-tasks',data);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Creator Dashboard'),actions:[
      IconButton(onPressed:_create,icon:const Icon(Icons.add),tooltip:'New task')]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
      RefreshIndicator(onRefresh:_load,child:ListView(children:[
        if(tasks.isEmpty)const ListTile(title:Text('No creator tasks yet')),
        ...tasks.map((t)=>ListTile(title:Text(field(t,'title')),
          subtitle:Text('${field(t,'status')} · ${field(t,'rewardBp')} BP'),
          onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LiveCreatorTaskEditor(task:obj(t)))).then((_){_load();}),
        )),
      ])),
  );
}

class LiveCreatorTaskEditor extends StatefulWidget{
  final Map<String,dynamic> task;
  const LiveCreatorTaskEditor({super.key,required this.task});
  @override State<LiveCreatorTaskEditor> createState()=>_CreatorEditState();
}
class _CreatorEditState extends State<LiveCreatorTaskEditor>{
  late final title=TextEditingController(text:field(widget.task,'title'));
  late final description=TextEditingController(text:field(widget.task,'description'));
  String status='DRAFT';bool busy=false;
  @override void initState(){super.initState();status=field(widget.task,'status','DRAFT');}
  @override void dispose(){title.dispose();description.dispose();super.dispose();}
  Future<void> _save()async{
    setState(()=>busy=true);
    try{
      final task=widget.task;
      final groups=arr(task['checklists']).map((group)=>({
        'id':field(group,'id'),'name':field(group,'name'),
        'items':arr(obj(group)['items']).map((item)=>({
          'id':field(item,'id'),'text':field(item,'text'),
          'rewardBp':double.tryParse(field(item,'rewardBp','0'))??0,
        })).toList(),
      })).toList();
      await LiveApi.call('PUT','/creator-tasks/${field(task,'id')}',{
        'title':title.text.trim(),'description':description.text.trim(),'status':status,
        'checklists':groups,
      });
      if(mounted)Navigator.pop(context);
    }catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Edit Creator Task')),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      TextField(controller:title,decoration:const InputDecoration(labelText:'Title')),
      TextField(controller:description,maxLines:4,decoration:const InputDecoration(labelText:'Description')),
      DropdownButton<String>(value:status,items:['DRAFT','PUBLISHED'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),
        onChanged:(v){if(v!=null)setState(()=>status=v);}),
      FilledButton(onPressed:busy?null:_save,child:const Text('Save Task')),
    ]));
}
