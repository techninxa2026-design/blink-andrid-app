import 'package:flutter/material.dart';
import '../core/live_api.dart';
import '../core/theme.dart';

class LiveCheckinsScreen extends StatefulWidget {
  const LiveCheckinsScreen({super.key});
  @override State<LiveCheckinsScreen> createState()=>_CheckinsState();
}
class _CheckinsState extends State<LiveCheckinsScreen>{
  List<dynamic> items=[];Map<String,dynamic> mine={};String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final data=await Future.wait([LiveApi.call('GET','/checkins'),LiveApi.call('GET','/checkins/mine')]);
      if(mounted)setState((){items=arr(data[0]);mine=obj(data[1]);loading=false;error=null;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _compose()async{
    final emoji=TextEditingController(text:field(mine,'emoji','🧡'));
    final status=TextEditingController(text:field(mine,'status'));
    final note=TextEditingController(text:field(mine,'note'));
    String duration=field(mine,'duration','24h');
    final form=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:Text(mine.isEmpty?'New Check-In':'Edit Check-In'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:emoji,decoration:const InputDecoration(labelText:'Emoji')),
        TextField(controller:status,decoration:const InputDecoration(labelText:'What are you doing?')),
        TextField(controller:note,maxLines:3,decoration:const InputDecoration(labelText:'Note (optional)')),
        DropdownButton<String>(value:duration,isExpanded:true,items:const [
          DropdownMenuItem(value:'24h',child:Text('24 hours')),
          DropdownMenuItem(value:'48h',child:Text('48 hours')),
          DropdownMenuItem(value:'until_removed',child:Text('Until I remove it')),
        ],onChanged:(v){if(v!=null)update(()=>duration=v);}),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,{'emoji':emoji.text.trim(),
          'status':status.text.trim(),'note':note.text.trim(),'duration':duration}),child:const Text('Save'))],
    )));
    emoji.dispose();status.dispose();note.dispose();
    if(form==null)return;
    try{await LiveApi.call(mine.isEmpty?'POST':'PATCH',mine.isEmpty?'/checkins':'/checkins/${field(mine,'id')}',form);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Blink Check-Ins'),actions:[
      IconButton(tooltip:mine.isEmpty?'Create Check-In':'Edit Check-In',onPressed:_compose,icon:Icon(mine.isEmpty?Icons.add:Icons.edit)),
    ]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
    RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
      if(items.isEmpty)const ListTile(title:Text('No active Check-Ins from your friends.')),
      ...items.map((raw){final item=obj(raw);final user=obj(item['user']);
        return Card(child:ListTile(leading:Text(field(item,'emoji'),style:const TextStyle(fontSize:30)),
          title:Text(field(user,'name','Blink member')+' · '+field(item,'status')),
          subtitle:Text(field(item,'note')+'\n'+field(item,'duration'),maxLines:4),
          trailing:field(item,'id')==field(mine,'id')?IconButton(
            icon:const Icon(Icons.delete_outline),onPressed:()async{
              try{await LiveApi.call('DELETE','/checkins/${field(item,'id')}');await _load();}
              catch(e){if(context.mounted)liveNotice(context,e.toString());}
            }):null,
        ));}),
    ])),
  );
}

class LiveSecretsScreen extends StatefulWidget{
  const LiveSecretsScreen({super.key});
  @override State<LiveSecretsScreen> createState()=>_SecretsState();
}
class _SecretsState extends State<LiveSecretsScreen>{
  List<dynamic> secrets=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final rows=arr(await LiveApi.call('GET','/secrets'));if(mounted)setState((){secrets=rows;error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _create()async{
    final prompt=TextEditingController();final options=TextEditingController();int correct=0;bool anonymous=true;int hours=24;
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:const Text('Create a Blink Secret'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:prompt,maxLines:3,decoration:const InputDecoration(labelText:'Question (5+ characters)')),
        TextField(controller:options,maxLines:5,decoration:const InputDecoration(labelText:'Options, one per line (2–5)')),
        DropdownButton<int>(value:correct,isExpanded:true,items:List.generate(5,(i)=>DropdownMenuItem(value:i,child:Text('Correct option: ${i+1}'))),
          onChanged:(v){if(v!=null)update(()=>correct=v);}),
        SwitchListTile(title:const Text('Anonymous'),value:anonymous,onChanged:(v)=>update(()=>anonymous=v)),
        DropdownButton<int>(value:hours,items:const [
          DropdownMenuItem(value:1,child:Text('Reveal in 1 hour')),
          DropdownMenuItem(value:24,child:Text('Reveal in 24 hours')),
          DropdownMenuItem(value:48,child:Text('Reveal in 48 hours')),
        ],onChanged:(v){if(v!=null)update(()=>hours=v);}),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:(){
          final opts=options.text.split('\n').map((e)=>e.trim()).where((e)=>e.isNotEmpty).toList();
          Navigator.pop(ctx,{'prompt':prompt.text.trim(),'options':opts,'correctIndex':correct,
            'visibility':anonymous?'ANONYMOUS':'NAMED',
            'revealAt':DateTime.now().toUtc().add(Duration(hours:hours)).toIso8601String()});
        },child:const Text('Publish'))],
    )));
    prompt.dispose();options.dispose();
    if(data==null)return;
    try{await LiveApi.call('POST','/secrets',data);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _act(String path,Map<String,dynamic> body)async{
    try{await LiveApi.call('POST',path,body);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Blink Secrets'),actions:[
      IconButton(onPressed:_create,tooltip:'New Secret',icon:const Icon(Icons.add_circle_outline)),
    ]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
    RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
      if(secrets.isEmpty)const ListTile(title:Text('No Secrets from your friends yet.')),
      ...secrets.map((raw){final item=obj(raw),id=field(item,'id');
        final selected=item['myGuess'];final options=arr(item['options']);final reveal=item['revealed']==true;
        return Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(
          crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(field(item,'prompt'),style:Theme.of(context).textTheme.titleMedium),
          Text(item['isMine']==true?'Your Secret':field(item['author'],'name','Anonymous'),
            style:const TextStyle(color:BlinkColors.orange)),
          ...options.asMap().entries.map((entry)=>RadioListTile<int>(
            title:Text(entry.value.toString()),
            value:entry.key,groupValue:selected is int?selected:null,
            onChanged:item['isMine']==true||selected!=null||reveal?null:(i){
              if(i!=null)_act('/secrets/$id/guess',{'selectedIndex':i});
            },
          )),
          if(reveal||item['isMine']==true)Text('Correct option: ${(item['correctIndex'] is int)?(item['correctIndex']+1):'Pending'}',
            style:const TextStyle(fontWeight:FontWeight.bold)),
          if(!reveal)Text('Reveal: ${field(item,'revealAt')}'),
          Wrap(spacing:8,children:['🧡','❤️','😮','😂','👏'].map((e)=>TextButton(
            onPressed:()=>_act('/secrets/$id/react',{'emoji':e}),
            child:Text(e))).toList()),
          Text('${field(item,'guessCount','0')} guesses · Earned ${field(item,'myReward','0')} BP'),
        ])));
      }),
    ])),
  );
}

class LiveHeartsScreen extends StatefulWidget{
  const LiveHeartsScreen({super.key});
  @override State<LiveHeartsScreen> createState()=>_HeartsState();
}
class _HeartsState extends State<LiveHeartsScreen>{
  List<dynamic> incoming=[],sent=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{final results=await Future.wait([LiveApi.call('GET','/hearts/incoming'),LiveApi.call('GET','/hearts/sent')]);
      if(mounted)setState((){incoming=arr(results[0]);sent=arr(results[1]);error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _send()async{
    final search=TextEditingController();final message=TextEditingController();
    List<dynamic> found=[];String? selectedId;
    final data=await showDialog<Map<String,String>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:const Text('Send an anonymous Heart'),
      content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:search,decoration:InputDecoration(labelText:'Find member',
          suffixIcon:IconButton(icon:const Icon(Icons.search),onPressed:()async{
            try{final r=arr(await LiveApi.call('GET','/hearts/people?search=${Uri.encodeQueryComponent(search.text.trim())}'));
              if(ctx.mounted)update(()=>found=r);
            }catch(e){if(ctx.mounted)liveNotice(ctx,e.toString());}
          }))),
        ...found.map((u)=>RadioListTile<String>(title:Text(field(u,'name')),value:field(u,'id'),
          groupValue:selectedId,onChanged:(v)=>update(()=>selectedId=v))),
        TextField(controller:message,maxLines:4,decoration:const InputDecoration(labelText:'Your private Heart message')),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:selectedId==null?null:()=>Navigator.pop(ctx,{'receiverId':selectedId!,'text':message.text}),
          child:const Text('Send Heart'))],
    )));
    search.dispose();message.dispose();
    if(data==null)return;
    try{await LiveApi.call('POST','/hearts',data);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Blink Hearts'),actions:[
      IconButton(tooltip:'Send Heart',onPressed:_send,icon:const Icon(Icons.favorite_border))]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
    RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
      const ListTile(title:Text('Received Hearts',style:TextStyle(fontWeight:FontWeight.bold))),
      ...incoming.map((x)=>_heartTile(x)),
      const Divider(),
      const ListTile(title:Text('Sent Hearts',style:TextStyle(fontWeight:FontWeight.bold))),
      ...sent.map((x)=>_heartTile(x)),
      if(incoming.isEmpty&&sent.isEmpty)const ListTile(title:Text('No Hearts yet')),
    ])),
  );
  Widget _heartTile(dynamic value){final heart=obj(value);final id=field(heart,'id');
    return Card(child:ListTile(
      leading:const CircleAvatar(child:Icon(Icons.favorite)),
      title:Text(field(heart['person'],'name',heart['side']=='incoming'?'Anonymous sender':'Blink member')),
      subtitle:Text(field(heart,'status','PENDING')),
      onTap:()=>Navigator.push(context,MaterialPageRoute<void>(builder:(_)=>LiveHeartThreadScreen(id:id))).then((_){_load();}),
    ));
  }
}

class LiveHeartThreadScreen extends StatefulWidget{
  final String id;
  const LiveHeartThreadScreen({super.key,required this.id});
  @override State<LiveHeartThreadScreen> createState()=>_HeartThreadState();
}
class _HeartThreadState extends State<LiveHeartThreadScreen>{
  final message=TextEditingController();Map<String,dynamic> data={};String? error;
  @override void initState(){super.initState();_load();}
  @override void dispose(){message.dispose();super.dispose();}
  Future<void> _load()async{
    try{final r=obj(await LiveApi.call('GET','/hearts/${Uri.encodeComponent(widget.id)}'));
      if(mounted)setState((){data=r;error=null;});}
    catch(e){if(mounted)setState(()=>error=e.toString());}
  }
  Future<void> _action(String suffix,[Map<String,dynamic>? body])async{
    try{await LiveApi.call('POST','/hearts/${widget.id}/$suffix',body);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }

  Future<void> _editMessage(dynamic raw)async{
    final item=obj(raw),id=field(item,'id');
    if(id.isEmpty||item['fromMe']!=true)return;
    final controller=TextEditingController(text:field(item,'text'));
    final edited=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:const Text('Edit Heart message'),
      content:TextField(controller:controller,maxLength:2000,maxLines:4,
        decoration:const InputDecoration(labelText:'Your Heart message')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),child:const Text('Save'))]));
    controller.dispose();
    if(edited==null||edited.isEmpty)return;
    try{
      await LiveApi.call('PATCH','/hearts/'+Uri.encodeComponent(widget.id)+
        '/messages/'+Uri.encodeComponent(id),{'text':edited});
      await _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }

  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Heart conversation')),body:Column(children:[
    if(error!=null)liveError(error,_load),
    if(data['side']=='incoming'&&data['status']=='PENDING')
      Row(mainAxisAlignment:MainAxisAlignment.center,children:[
        TextButton(onPressed:()=>_action('respond',{'status':'ACCEPTED'}),child:const Text('Accept')),
        TextButton(onPressed:()=>_action('respond',{'status':'DECLINED'}),child:const Text('Decline')),
      ]),
    if(data['side']=='sent'&&data['revealed']!=true)
      TextButton(onPressed:()=>_action('reveal'),child:const Text('Reveal my identity')),
    if(data['side']=='incoming'&&data['blockedByMe']!=true)
      TextButton(onPressed:()=>_action('block'),child:const Text('Block sender')),
    Expanded(child:ListView(padding:const EdgeInsets.all(15),children:arr(data['messages']).map((m)=>Card(
      child:ListTile(title:Text(field(m,'text')),
        subtitle:obj(m)['editedAt']!=null?const Text('Edited'):null,
        trailing:obj(m)['fromMe']==true?IconButton(
          tooltip:'Edit Heart message',onPressed:()=>_editMessage(m),
          icon:const Icon(Icons.edit_outlined,color:BlinkColors.orange)):null))).toList())),
    SafeArea(top:false,child:Row(children:[
      Expanded(child:TextField(controller:message,decoration:const InputDecoration(hintText:'Write a Heart reply...'))),
      IconButton(onPressed:()async{if(message.text.trim().isEmpty)return;
        await _action('messages',{'text':message.text.trim()});message.clear();},
        icon:const Icon(Icons.send,color:BlinkColors.orange)),
    ])),
  ]));
}

class LiveIrlScreen extends StatefulWidget{
  const LiveIrlScreen({super.key});
  @override State<LiveIrlScreen> createState()=>_IrlState();
}
class _IrlState extends State<LiveIrlScreen>{
  List<dynamic> plans=[];String? error;bool loading=true;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{try{final r=arr(await LiveApi.call('GET','/irl/plans'));
      if(mounted)setState((){plans=r;error=null;loading=false;});}
    catch(e){if(mounted)setState((){error=e.toString();loading=false;});}}
  Future<void> _create()async{
    final title=TextEditingController(),desc=TextEditingController(),place=TextEditingController();
    var start=DateTime.now().add(const Duration(days:1));var category='Hangout';
    final data=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
      title:const Text('Create IRL plan'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:title,decoration:const InputDecoration(labelText:'Title')),
        TextField(controller:desc,decoration:const InputDecoration(labelText:'Description')),
        TextField(controller:place,decoration:const InputDecoration(labelText:'Place')),
        DropdownButton<String>(value:category,isExpanded:true,items:['Hangout','Sports','Gaming','Food','Shopping','Other']
          .map((v)=>DropdownMenuItem(value:v,child:Text(v))).toList(),onChanged:(v){if(v!=null)update(()=>category=v);}),
        TextButton.icon(icon:const Icon(Icons.event),label:Text('Starts: ${start.toLocal()}'),
          onPressed:()async{final d=await showDatePicker(context:ctx,firstDate:DateTime.now(),lastDate:DateTime.now().add(const Duration(days:365)),initialDate:start);
            if(d==null||!ctx.mounted)return;
            final t=await showTimePicker(context:ctx,initialTime:TimeOfDay.fromDateTime(start));
            if(t!=null)update(()=>start=DateTime(d.year,d.month,d.day,t.hour,t.minute));}),
      ])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,{'title':title.text,'category':category,
          'description':desc.text,'place':place.text,'startsAt':start.toUtc().toIso8601String()}),
          child:const Text('Create'))],
    )));
    title.dispose();desc.dispose();place.dispose();
    if(data==null)return;
    try{await LiveApi.call('POST','/irl/plans',data);await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  Future<void> _interest(String id)async{
    try{await LiveApi.call('POST','/irl/plans/$id/interest',{'reply':'Interested in joining'});await _load();}
    catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('IRL Plans'),actions:[
      IconButton(tooltip:'Create plan',onPressed:_create,icon:const Icon(Icons.add))]),
    body:loading?const Center(child:CircularProgressIndicator()):error!=null?liveError(error,_load):
      RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(12),children:[
        if(plans.isEmpty)const ListTile(title:Text('No plans from your Blink friends yet.')),
        ...plans.map((p){final plan=obj(p);final id=field(plan,'id');
          return Card(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(field(plan,'title'),style:Theme.of(context).textTheme.titleMedium),
            Text(field(plan,'category')+' · '+field(plan,'place')),
            Text(field(plan,'description')),
            Text('Starts: ${field(plan,'startsAt')}'),
            Wrap(children:[
              TextButton(onPressed:()=>_interest(id),child:const Text('Interested')),
              TextButton(onPressed:()=>Navigator.push(context,MaterialPageRoute<void>(
                builder:(_)=>LiveIrlChatScreen(planId:id,title:field(plan,'title')))),
                child:const Text('Plan chat')),
            ]),
          ])));
        }),
      ])),
  );
}

class LiveIrlChatScreen extends StatefulWidget{
  final String planId,title;
  const LiveIrlChatScreen({super.key,required this.planId,required this.title});
  @override State<LiveIrlChatScreen> createState()=>_IrlChatState();
}
class _IrlChatState extends State<LiveIrlChatScreen>{
  final text=TextEditingController();List<dynamic> messages=[];String? error;
  @override void initState(){super.initState();_load();}
  @override void dispose(){text.dispose();super.dispose();}
  Future<void> _load()async{try{final data=obj(await LiveApi.call('GET','/irl/plans/${widget.planId}/messages'));
      if(mounted)setState((){messages=arr(data['messages']);error=null;});}
    catch(e){if(mounted)setState(()=>error=e.toString());}}
  Future<void> _send()async{
    try{await LiveApi.call('POST','/irl/plans/${widget.planId}/messages',{'text':text.text.trim()});
      text.clear();await _load();
    }catch(e){if(mounted)liveNotice(context,e.toString());}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:Text(widget.title)),body:Column(children:[
    if(error!=null)liveError(error,_load),
    Expanded(child:ListView(children:messages.map((m)=>ListTile(
      title:Text(field(obj(m)['sender'],'name','Blink member')),subtitle:Text(field(m,'text')))).toList())),
    SafeArea(top:false,child:Row(children:[Expanded(child:TextField(controller:text,decoration:const InputDecoration(hintText:'Message...'))),
      IconButton(onPressed:_send,icon:const Icon(Icons.send,color:BlinkColors.orange))])),
  ]));
}
