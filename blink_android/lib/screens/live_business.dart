import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import '../core/live_api.dart';
import '../core/theme.dart';

class LiveBusinessScreen extends StatefulWidget {
  const LiveBusinessScreen({super.key});
  @override State<LiveBusinessScreen> createState()=>_BusinessState();
}
class _BusinessState extends State<LiveBusinessScreen>{
  Map<String,dynamic> profile={};List<dynamic> matches=[],requests=[],connections=[];
  String query='',type='';int page=1;String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{
      final p=obj(await LiveApi.call('GET','/business-match/me'));
      List<dynamic> found=[],req=[],con=[];
      if(p['active']==true){
        final results=await Future.wait([
          LiveApi.call('GET','/business-match/discover?q='+Uri.encodeQueryComponent(query)+'&page='+page.toString()+(type.isEmpty?'':'&type='+type)),
          LiveApi.call('GET','/business-match/requests'),
          LiveApi.call('GET','/business-match/connections'),
        ]);
        found=arr(results[0]);req=arr(results[1]);con=arr(results[2]);
      }
      if(mounted)setState((){profile=p;matches=found;requests=req;connections=con;error=null;loading=false;});
    }catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _edit()async{
    final values=<String,TextEditingController>{
      for(final k in ['name','headline','industry','location','skills','about','lookingFor'])
        k:TextEditingController(text:field(profile,k)),
    };
    String kind=field(profile,'type','PROFESSIONAL');
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:const Text('Business / Professional Profile'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        DropdownButton<String>(value:kind,isExpanded:true,items:const [
          DropdownMenuItem(value:'PROFESSIONAL',child:Text('Individual Professional')),
          DropdownMenuItem(value:'COMPANY',child:Text('Company')),
        ],onChanged:(v){if(v!=null)update(()=>kind=v);}),
        ...values.entries.map((entry)=>TextField(controller:entry.value,maxLines:entry.key=='about'?3:1,
          decoration:InputDecoration(labelText:entry.key))),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,{
          'type':kind,...values.map((key,value)=>MapEntry(key,value.text.trim())),
        }),child:const Text('Save'))],
    )));
    for(final c in values.values){c.dispose();}
    if(data==null)return;
    try{await LiveApi.call('PUT','/business-match/me',data);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _activation(bool value)async{
    try{await LiveApi.call('PATCH','/business-match/me/activation',{'active':value});await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }

  Future<void> _profileDetails(String id)async{
    try{
      final p=obj(await LiveApi.call('GET','/business-match/profiles/'+Uri.encodeComponent(id)));
      if(!mounted)return;
      await showModalBottomSheet<void>(context:context,isScrollControlled:true,
        builder:(ctx)=>SafeArea(child:ListView(shrinkWrap:true,
          padding:const EdgeInsets.all(18),children:[
            Text(field(p,'name'),style:Theme.of(ctx).textTheme.titleLarge),
            Text(field(p,'headline')),
            const SizedBox(height:12),
            Text('Profile type: '+field(p,'type')),
            Text('Industry: '+field(p,'industry')),
            Text('Location: '+field(p,'location')),
            Text('Skills: '+field(p,'skills')),
            Text('About: '+field(p,'about')),
            Text('Looking for: '+field(p,'lookingFor')),
            const SizedBox(height:16),
            FilledButton.icon(onPressed:(){Navigator.pop(ctx);_send(id);},
              icon:const Icon(Icons.person_add_alt_outlined),
              label:const Text('Send connection request')),
          ])));
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }

  Future<void> _send(String id)async{
    try{await LiveApi.call('POST','/business-match/requests',{'profileId':id});await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _respond(String id,bool accept)async{
    try{await LiveApi.call('PATCH','/business-match/requests/$id',{'accept':accept});await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const BlinkBrandedTitle('Business Match'),actions:[
      IconButton(tooltip:'Edit business profile',icon:const Icon(Icons.manage_accounts),onPressed:_edit),
      IconButton(tooltip:'Refresh',icon:const Icon(Icons.refresh),onPressed:_load),
    ]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
      RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
        Card(child:SwitchListTile.adaptive(
          title:Text(field(profile,'name','Create a professional profile')),
          subtitle:Text(field(profile,'headline','Add your experience to discover opportunities')),
          value:profile['active']==true,onChanged:profile.isEmpty?null:_activation,
          activeTrackColor:BlinkColors.orange,
        )),
        if(profile.isEmpty)FilledButton(onPressed:_edit,child:const Text('Create Business Profile')),
        if(profile['active']==true)...[
          Padding(padding:const EdgeInsets.all(10),child:TextField(
            decoration:InputDecoration(hintText:'Search connections',
              suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:_load)),
            onChanged:(v)=>query=v,onSubmitted:(_){page=1;_load();})),
          DropdownButtonFormField<String>(initialValue:type,
            decoration:const InputDecoration(labelText:'Profile type'),
            items:const [DropdownMenuItem(value:'',child:Text('All profiles')),
              DropdownMenuItem(value:'PROFESSIONAL',child:Text('Professionals')),
              DropdownMenuItem(value:'COMPANY',child:Text('Companies'))],
            onChanged:(v){type=v??'';page=1;_load();}),
          const ListTile(title:Text('Discover professionals',style:TextStyle(fontWeight:FontWeight.bold))),
          ...matches.map((m)=>Card(child:ListTile(title:Text(field(m,'name')),
            subtitle:Text(field(m,'headline')+' · '+field(m,'industry')),
            onTap:()=>_profileDetails(field(m,'id')),
            trailing:IconButton(tooltip:'Connect',icon:const Icon(Icons.person_add),onPressed:()=>_send(field(m,'id')))))),
          Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            TextButton(onPressed:page>1?(){page--;_load();}:null,child:const Text('Previous')),
            Text('Page $page'),
            TextButton(onPressed:matches.length==20?(){page++;_load();}:null,child:const Text('Next')),
          ]),
          const ListTile(title:Text('Requests',style:TextStyle(fontWeight:FontWeight.bold))),
          ...requests.map((r)=>ListTile(
            title:Text(field(obj(r)['profile'],'name')),
            subtitle:Text(field(r,'direction')),
            trailing:field(r,'direction')=='incoming'
              ?Wrap(spacing:4,children:[
                TextButton(onPressed:()=>_respond(field(r,'id'),true),child:const Text('Accept')),
                TextButton(onPressed:()=>_respond(field(r,'id'),false),child:const Text('Decline'))])
              :IconButton(icon:const Icon(Icons.close),onPressed:()async{
                try{await LiveApi.call('DELETE','/business-match/requests/${field(r,'id')}');await _load();}
                catch(e){if(context.mounted)liveNotice(context,e.toString());}
              }),
          )),
          const ListTile(title:Text('Business Connections',style:TextStyle(fontWeight:FontWeight.bold))),
          ...connections.map((m)=>ListTile(title:Text(field(obj(m)['profile'],'name')),
            subtitle:Text(field(obj(m)['profile'],'headline')),
            onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>
              LiveBusinessChat(connectionId:field(m,'id'),name:field(obj(m)['profile'],'name')))))),
          FilledButton.icon(onPressed:()=>Navigator.push(context,
            MaterialPageRoute<void>(builder:(_)=>const LiveBusinessMeetings())),
            icon:const Icon(Icons.event),label:const Text('Business Meetings')),
        ],
      ])),
  );
}

class LiveBusinessChat extends StatefulWidget{
  final String connectionId,name;
  const LiveBusinessChat({super.key,required this.connectionId,required this.name});
  @override State<LiveBusinessChat> createState()=>_BusinessChatState();
}
class _BusinessChatState extends State<LiveBusinessChat>{
  final message=TextEditingController();List<dynamic> items=[];String? error;bool busy=false;
  @override void initState(){super.initState();_load();}
  @override void dispose(){message.dispose();super.dispose();}
  Future<void> _load()async{try{
    final r=await LiveApi.call('GET','/business-match/chats/${widget.connectionId}/messages');
    if(mounted)setState((){items=r is List?r:arr(obj(r)['messages']);error=null;});}
    catch(e){if(mounted)setState(()=>error=e.toString());}}
  Future<void> _send()async{
    if(message.text.trim().isEmpty||busy)return;setState(()=>busy=true);
    try{await LiveApi.call('POST','/business-match/chats/${widget.connectionId}/messages',
      {'text':message.text.trim()});message.clear();await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.name)),
    body:Column(children:[
      if(error!=null)liveError(error,_load),
      Expanded(child:ListView(children:items.map((m)=>ListTile(
        title:Text(field(m,'text',field(m,'body'))),
        subtitle:Text(field(m,'createdAt')))).toList())),
      SafeArea(top:false,child:Row(children:[
        Expanded(child:TextField(controller:message,decoration:const InputDecoration(hintText:'Business message...'))),
        IconButton(onPressed:busy?null:_send,icon:const Icon(Icons.send,color:BlinkColors.orange)),
      ])),
    ]));
}

class LiveBusinessMeetings extends StatefulWidget{
  const LiveBusinessMeetings({super.key});
  @override State<LiveBusinessMeetings> createState()=>_MeetingsState();
}
class _MeetingsState extends State<LiveBusinessMeetings>{
  List<dynamic> meetings=[];String? error;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=arr(await LiveApi.call('GET','/business-match/meetings'));
      if(mounted)setState((){meetings=rows;error=null;});}
    catch(e){if(mounted)setState(()=>error=e.toString());}}

  Future<void> _create()async{
    try{
      final connections=arr(await LiveApi.call('GET','/business-match/connections'));
      if(!mounted)return;
      if(connections.isEmpty){
        liveNotice(context,'Connect with a business partner before scheduling a meeting.');
        return;
      }
      final title=TextEditingController(),agenda=TextEditingController(),location=TextEditingController();
      String connectionId=field(connections.first,'id');
      var startsAt=DateTime.now().add(const Duration(days:1));
      var endsAt=startsAt.add(const Duration(hours:1));
      final values=await showDialog<Map<String,dynamic>>(context:context,
        builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
          title:const Text('Schedule Business Meeting'),
          content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
            DropdownButtonFormField<String>(initialValue:connectionId,
              decoration:const InputDecoration(labelText:'Business connection'),
              items:connections.map((c)=>DropdownMenuItem(
                value:field(c,'id'),child:Text(field(obj(c)['profile'],'name','Partner')))).toList(),
              onChanged:(v){if(v!=null)update(()=>connectionId=v);}),
            TextField(controller:title,maxLength:120,
              decoration:const InputDecoration(labelText:'Meeting title')),
            TextField(controller:agenda,maxLength:1000,maxLines:3,
              decoration:const InputDecoration(labelText:'Agenda')),
            TextField(controller:location,maxLength:300,
              decoration:const InputDecoration(labelText:'Meeting link or location')),
            TextButton.icon(icon:const Icon(Icons.event),label:Text('Starts: '+startsAt.toString().substring(0,16)),
              onPressed:()async{
                final date=await showDatePicker(context:ctx,initialDate:startsAt,
                  firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)));
                if(date==null||!ctx.mounted)return;
                final tm=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(startsAt));
                if(tm!=null)update((){
                  startsAt=DateTime(date.year,date.month,date.day,tm.hour,tm.minute);
                  endsAt=startsAt.add(const Duration(hours:1));
                });
              }),
            TextButton.icon(icon:const Icon(Icons.access_time),label:Text('Ends: '+endsAt.toString().substring(0,16)),
              onPressed:()async{
                final tm=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(endsAt));
                if(tm!=null)update(()=>endsAt=DateTime(
                  startsAt.year,startsAt.month,startsAt.day,tm.hour,tm.minute));
              }),
            const Text('Meeting duration must be 8 hours or less.'),
          ])),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
            FilledButton(onPressed:()=>Navigator.pop(ctx,{
              'connectionId':connectionId,'title':title.text.trim(),
              'agenda':agenda.text.trim(),'location':location.text.trim(),
              'startsAt':startsAt.toUtc().toIso8601String(),
              'endsAt':endsAt.toUtc().toIso8601String(),
            }),child:const Text('Schedule'))],
        )));
      title.dispose();agenda.dispose();location.dispose();
      if(values==null)return;
      await LiveApi.call('POST','/business-match/meetings',values);
      await _load();
      if(mounted)liveNotice(context,'Meeting invitation sent.');
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }

  Future<void> _action(String id,String action)async{
    try{await LiveApi.call('PATCH','/business-match/meetings/$id/$action');await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('Business Meetings'),actions:[
      IconButton(tooltip:'Schedule meeting',onPressed:_create,
        icon:const Icon(Icons.add_circle_outline))]),
    body:error!=null?liveError(error,_load):RefreshIndicator(onRefresh:_load,
      child:ListView(children:[
        if(meetings.isEmpty)const ListTile(title:Text('No meetings scheduled')),
        ...meetings.map((m)=>Card(child:Column(children:[
          ListTile(title:Text(field(m,'title','Meeting')),
            subtitle:Text('${field(m,'status')} · ${field(m,'startsAt')}')),
          Wrap(children:[
            TextButton(onPressed:()=>_action(field(m,'id'),'accept'),child:const Text('Accept')),
            TextButton(onPressed:()=>_action(field(m,'id'),'decline'),child:const Text('Decline')),
            TextButton(onPressed:()=>_action(field(m,'id'),'cancel'),child:const Text('Cancel')),
          ]),
        ]))),
      ])),
  );
}
