import 'package:flutter/material.dart';
import '../widgets/ui.dart';
import '../core/blink_auth_api.dart';
import '../core/live_api.dart';
import '../core/theme.dart';
import 'task_participation.dart';

class FullTaskReviews extends StatefulWidget {
  const FullTaskReviews({super.key,required this.taskId});
  final String taskId;
  @override State<FullTaskReviews> createState()=>_ReviewState();
}
class _ReviewState extends State<FullTaskReviews>{
  Map<String,dynamic> data={};
  String filter='SUBMITTED',error='',token='';
  bool loading=true,busy=false;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{
    try{
      final values=await Future.wait<dynamic>([
        LiveApi.call('GET','/creator-tasks/'+Uri.encodeComponent(widget.taskId)+'/submissions'),
        BlinkAuthApi.getToken(),
      ]);
      if(mounted)setState((){
        data=obj(values[0]);token=(values[1]??'').toString();error='';loading=false;
      });
    }catch(e){if(mounted)setState((){error=e.toString();loading=false;});}
  }
  Future<void> _review(Map<String,dynamic> participant,Map<String,dynamic> step,
      String verdict)async{
    if(busy)return;
    final controller=TextEditingController();
    final message=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(verdict=='APPROVED'?'Approve checklist response?':'Reject checklist response?'),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(field(step,'title')+' · '+field(step,'rewardBp')+' BP'),
        const SizedBox(height:12),
        TextField(controller:controller,maxLength:500,maxLines:3,
          decoration:const InputDecoration(labelText:'Review note (optional)')),
      ]),
      actions:[
        TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,controller.text.trim()),
          child:const Text('Confirm')),
      ]));
    controller.dispose();
    if(message==null)return;
    setState(()=>busy=true);
    try{
      final result=obj(await LiveApi.call('POST',
        '/creator-tasks/'+Uri.encodeComponent(widget.taskId)+
        '/submissions/'+Uri.encodeComponent(field(participant,'id'))+
        '/steps/'+Uri.encodeComponent(field(step,'id'))+'/review',{
          'decision':verdict,
          if(message.isNotEmpty)'note':message,
        }));
      await _load();
      if(mounted)liveNotice(context,field(result,'status')=='REVIEWED'
        ?'Verification complete. Approved BP credited by the server.'
        :'Response reviewed. Continue with the other pending items.');
    }catch(e){if(mounted)liveNotice(context,e.toString());}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> _video(String id)async{
    try{
      final result=obj(await LiveApi.call('GET','/task-participations/videos/'+
        Uri.encodeComponent(id)+'/playback'));
      final url=field(result,'url');
      if(url.isEmpty)throw const LiveApiError('Video URL unavailable.');
      if(!mounted)return;
      Navigator.push<void>(context,MaterialPageRoute(builder:(_)=>Scaffold(
        appBar:AppBar(title:const BlinkBrandedTitle('Evidence video')),
        body:TaskMediaVideo(url:LiveApi.root+url))));
    }catch(e){if(mounted)liveNotice(context,e.toString());}
  }
  @override Widget build(BuildContext context){
    final entries=arr(data['submissions']).where((p)=>filter=='ALL'||
      field(p,'status')==filter).toList();
    return Scaffold(appBar:AppBar(title:const BlinkBrandedTitle('Task Verification'),
      actions:[IconButton(tooltip:'Refresh',onPressed:_load,icon:const Icon(Icons.refresh))]),
      body:loading?const Center(child:CircularProgressIndicator(color:BlinkColors.orange))
      :error.isNotEmpty?liveError(error,_load)
      :ListView(padding:const EdgeInsets.all(12),children:[
        Text(field(data['task'],'title'),style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),
        BlinkAdaptiveSegments<String>(segments:const [
          ButtonSegment(value:'SUBMITTED',label:Text('Pending')),
          ButtonSegment(value:'REVIEWED',label:Text('Reviewed')),
          ButtonSegment(value:'ALL',label:Text('All')),
        ],selected:{filter},onChanged:(value)=>setState(()=>filter=value.first)),
        if(entries.isEmpty)const ListTile(title:Text('No submissions in this category.')),
        ...entries.map((raw){
          final person=obj(raw);
          return Card(child:ExpansionTile(
            title:Text(field(person['participant'],'name','Participant')),
            subtitle:Text(field(person,'status')+' · '+field(person,'earnedBp','0')+' BP earned'),
            children:arr(person['steps']).map((rawStep){
              final step=obj(rawStep);
              return Padding(padding:const EdgeInsets.all(12),child:Column(
                crossAxisAlignment:CrossAxisAlignment.start,children:[
                  Text(field(step,'group')+' / '+field(step,'title'),
                    style:const TextStyle(fontWeight:FontWeight.w800)),
                  Text(field(step,'explanation')),
                  Text('Reward: '+field(step,'rewardBp')+' BP · '+field(step,'status')),
                  if(field(step,'note').isNotEmpty)Text('Creator note: '+field(step,'note')),
                  if(arr(step['imageIds']).isNotEmpty)SizedBox(height:110,
                    child:ListView(scrollDirection:Axis.horizontal,children:[
                      ...arr(step['imageIds']).map((image)=>Padding(
                        padding:const EdgeInsets.only(right:6),
                        child:Image.network(LiveApi.root+'/task-participations/images/'+
                          Uri.encodeComponent(image.toString()),
                          headers:{'Authorization':'Bearer $token'},
                          width:130,height:105,fit:BoxFit.cover,
                          errorBuilder:(_,__,___)=>const Icon(Icons.broken_image_outlined)))),
                    ])),
                  if(field(step,'videoUploadId').isNotEmpty)
                    TextButton.icon(onPressed:()=>_video(field(step,'videoUploadId')),
                      icon:const Icon(Icons.play_circle_outline),
                      label:const Text('Watch evidence video')),
                  if(field(step,'status')=='PENDING')
                    Row(children:[
                      FilledButton(onPressed:busy?null:()=>_review(person,step,'APPROVED'),
                        child:const Text('Approve')),
                      const SizedBox(width:8),
                      OutlinedButton(onPressed:busy?null:()=>_review(person,step,'REJECTED'),
                        child:const Text('Reject')),
                    ]),
                  const Divider(),
                ]));
            }).toList(),
          ));
        }),
      ]),
    );
  }
}
