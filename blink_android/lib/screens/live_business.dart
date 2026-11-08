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
  Future<void> _edit() async {
    const keys = ['name', 'headline', 'industry', 'location',
      'skills', 'about', 'lookingFor'];
    const labels = <String, String>{
      'name': 'Business or professional name',
      'headline': 'Professional headline',
      'industry': 'Industry',
      'location': 'Location',
      'skills': 'Skills and specialties',
      'about': 'About you or your company',
      'lookingFor': 'Looking for',
    };
    final values = <String, TextEditingController>{
      for (final key in keys)
        key: TextEditingController(text: field(profile, key)),
    };
    String kind = field(profile, 'type', 'PROFESSIONAL');
    if (kind != 'PROFESSIONAL' && kind != 'COMPANY') kind = 'PROFESSIONAL';
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => BlinkFormDialog(
          title: 'Business Profile',
          subtitle: 'Let people discover who you are and what you offer.',
          icon: Icons.business_center_outlined,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: kind,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Profile type'),
                items: const [
                  DropdownMenuItem(value: 'PROFESSIONAL',
                    child: Text('Individual Professional')),
                  DropdownMenuItem(value: 'COMPANY',
                    child: Text('Company')),
                ],
                onChanged: (v) {
                  if (v != null) update(() => kind = v);
                },
              ),
              const SizedBox(height: 14),
              ...values.entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextField(
                  controller: entry.value,
                  maxLines: entry.key == 'about' ? 4 : 1,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: (_) => update(() {}),
                  decoration: InputDecoration(
                    labelText: labels[entry.key],
                    alignLabelWithHint: entry.key == 'about',
                  ),
                ),
              )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
            FilledButton(
              onPressed: values['name']!.text.trim().isEmpty
                ? null
                : () => Navigator.pop(ctx, <String, dynamic>{
                    'type': kind,
                    ...values.map((key, value) =>
                      MapEntry(key, value.text.trim())),
                  }),
              child: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
    for (final controller in values.values) {
      controller.dispose();
    }
    if (data == null) return;
    try {
      await LiveApi.call('PUT', '/business-match/me', data);
      await _load();
    } catch (error) {
      if (mounted) liveNotice(context, error.toString());
    }
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
const BlinkFeatureHero(eyebrow:'YOUR PROFESSIONAL WORLD',title:'People. Purpose. Possibility.',subtitle:'Build a credible presence, find collaborators and make real business connections.',icon:Icons.business_center_rounded,mood:BlinkMood.business,margin:EdgeInsets.fromLTRB(0,0,0,18)),
        BlinkProCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('YOUR PROFESSIONAL IDENTITY',style:TextStyle(
            letterSpacing:1.1,fontWeight:FontWeight.w900,fontSize:10,
            color:BlinkColors.orangeDark)),
          SwitchListTile.adaptive(
            contentPadding:EdgeInsets.zero,
            title:Text(field(profile,'name','Create a professional profile'),
              style:const TextStyle(fontWeight:FontWeight.w800)),
            subtitle:Text(field(profile,'headline',
              'Add your experience to discover opportunities')),
            value:profile['active']==true,onChanged:profile.isEmpty?null:_activation,
            activeTrackColor:BlinkColors.orange,
          ),
        ])),
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
          ...matches.map((m)=>BlinkProListCard(
            icon:field(m,'type')=='COMPANY'
              ?Icons.business_center_rounded:Icons.person_search_rounded,
            eyebrow:field(m,'type')=='COMPANY'?'COMPANY PROFILE':'BLINK PROFESSIONAL',
            title:field(m,'name'),
            subtitle:field(m,'headline'),
            badges:[
              if(field(m,'industry').isNotEmpty)
                BlinkInfoPill(field(m,'industry'),icon:Icons.work_outline_rounded,highlight:true),
              if(field(m,'location').isNotEmpty)
                BlinkInfoPill(field(m,'location'),icon:Icons.location_on_outlined),
            ],
            onTap:()=>_profileDetails(field(m,'id')),
            footer:Row(children:[
              Expanded(child:OutlinedButton.icon(
                onPressed:()=>_profileDetails(field(m,'id')),
                icon:const Icon(Icons.visibility_outlined,size:17),
                label:const Text('Profile'))),
              const SizedBox(width:8),
              Expanded(child:FilledButton.icon(
                onPressed:()=>_send(field(m,'id')),
                icon:const Icon(Icons.person_add_alt_1_rounded,size:17),
                label:const Text('Connect'))),
            ]),
          )),
          Row(mainAxisAlignment:MainAxisAlignment.center,children:[
            TextButton(onPressed:page>1?(){page--;_load();}:null,child:const Text('Previous')),
            Text('Page $page'),
            TextButton(onPressed:matches.length==20?(){page++;_load();}:null,child:const Text('Next')),
          ]),
          const ListTile(title:Text('Requests',style:TextStyle(fontWeight:FontWeight.bold))),
          ...requests.map((r)=>BlinkProListCard(
            title:field(obj(r)['profile'],'name','Professional'),
            subtitle:field(r,'direction')=='incoming'
              ?'Wants to connect with you':'Request awaiting a response',
            eyebrow:'BUSINESS CONNECTION REQUEST',
            icon:Icons.mark_email_unread_outlined,
            badges:[BlinkInfoPill(field(r,'direction'),icon:Icons.schedule_outlined)],
            footer:Wrap(spacing:8,runSpacing:4,children:[
              if(field(r,'direction')=='incoming')...[
                FilledButton.icon(onPressed:()=>_respond(field(r,'id'),true),
                  icon:const Icon(Icons.check,size:18),label:const Text('Accept')),
                OutlinedButton(onPressed:()=>_respond(field(r,'id'),false),
                  child:const Text('Decline')),
              ]else OutlinedButton.icon(
                icon:const Icon(Icons.close,size:18),label:const Text('Cancel request'),
                onPressed:()async{
                  try{await LiveApi.call('DELETE','/business-match/requests/${field(r,'id')}');await _load();}
                  catch(e){if(context.mounted)liveNotice(context,e.toString());}
                }),
            ]),
          )),
          const ListTile(title:Text('Business Connections',style:TextStyle(fontWeight:FontWeight.bold))),
          ...connections.map((m)=>BlinkProListCard(
            title:field(obj(m)['profile'],'name','Connection'),
            subtitle:field(obj(m)['profile'],'headline'),
            eyebrow:'YOUR BUSINESS NETWORK',
            icon:Icons.handshake_outlined,
            badges:const [BlinkInfoPill('Connected',icon:Icons.verified_outlined,highlight:true)],
            onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>
              LiveBusinessChat(connectionId:field(m,'id'),name:field(obj(m)['profile'],'name')))),
          )),
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
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:BlinkBrandedTitle(widget.name)),
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
        builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>BlinkFormDialog(
          title:'Schedule Business Meeting',
          subtitle:'Invite a connection and set a clear time and agenda.',
          icon:Icons.event_available_outlined,
          content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
            DropdownButtonFormField<String>(initialValue:connectionId,isExpanded:true,
              decoration:const InputDecoration(labelText:'Business connection'),
              items:connections.map((c)=>DropdownMenuItem(
                value:field(c,'id'),child:Text(field(obj(c)['profile'],'name','Partner'),overflow:TextOverflow.ellipsis))).toList(),
              onChanged:(v){if(v!=null)update(()=>connectionId=v);}),
            const SizedBox(height:12),
            TextField(controller:title,maxLength:120,
              textCapitalization:TextCapitalization.sentences,
              onChanged:(_)=>update((){}),
              decoration:const InputDecoration(labelText:'Meeting title')),
            const SizedBox(height:7),
            TextField(controller:agenda,maxLength:1000,maxLines:3,
              textCapitalization:TextCapitalization.sentences,
              decoration:const InputDecoration(labelText:'Agenda',alignLabelWithHint:true)),
            const SizedBox(height:7),
            TextField(controller:location,maxLength:300,
              decoration:const InputDecoration(labelText:'Meeting link or location')),
            const SizedBox(height:9),
            OutlinedButton.icon(icon:const Icon(Icons.event),label:Text('Starts: '+startsAt.toString().substring(0,16),maxLines:1,overflow:TextOverflow.ellipsis),
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
            OutlinedButton.icon(icon:const Icon(Icons.access_time),label:Text('Ends: '+endsAt.toString().substring(0,16),maxLines:1,overflow:TextOverflow.ellipsis),
              onPressed:()async{
                final tm=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(endsAt));
                if(tm!=null)update(()=>endsAt=DateTime(
                  startsAt.year,startsAt.month,startsAt.day,tm.hour,tm.minute));
              }),
            const Text('Meeting duration must be 8 hours or less.',style:TextStyle(fontSize:12,color:BlinkColors.muted)),
          ])),
          actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
            FilledButton(onPressed:title.text.trim().isEmpty || !endsAt.isAfter(startsAt) ||
              endsAt.difference(startsAt).inMinutes>480 ? null : ()=>Navigator.pop(ctx,{
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
        ...meetings.map((m)=>BlinkProListCard(
          title:field(m,'title','Meeting'),
          subtitle:field(m,'agenda'),
          eyebrow:'BUSINESS MEETING',
          icon:Icons.event_available_outlined,
          badges:[
            BlinkInfoPill(field(m,'status'),icon:Icons.schedule_outlined,highlight:true),
            BlinkInfoPill(field(m,'startsAt'),icon:Icons.calendar_month_outlined),
          ],
          footer:Wrap(spacing:8,runSpacing:4,children:[
            TextButton(onPressed:()=>_action(field(m,'id'),'accept'),child:const Text('Accept')),
            TextButton(onPressed:()=>_action(field(m,'id'),'decline'),child:const Text('Decline')),
            TextButton(onPressed:()=>_action(field(m,'id'),'cancel'),child:const Text('Cancel')),
          ]),
        )),
      ])),
  );
}
