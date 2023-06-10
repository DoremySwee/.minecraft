#loader crafttweaker reloadableevents
#priority 1000000004

import scripts.libs.Vector3D as V;
import scripts.libs.Misc as M;
import scripts.libs.Data as D;

import crafttweaker.player.IPlayer;
import crafttweaker.world.IWorld;
import crafttweaker.data.IData;

import mods.zenutils.NetworkHandler;
import mods.zenutils.IByteBuf;


zenClass FXGenerator{
    var name as string;
    var ticking as [function(IWorld, IData)IData] = [];
    var renderClient as function(IPlayer, IData)void = null;
    var renderRegistered as bool= false;
    var objects as [IData][int] = {};
    zenConstructor(nameIn as string){
        ticking = [];
        name = nameIn;
    }
    function addTick(f as function(IWorld, IData)IData)as FXGenerator{
        ticking+=f;
        return this;
    }
    function setRender(f as function(IPlayer, IData)void)as FXGenerator{
        renderClient = f;   renderRegistered=true;
        return this;
    }
    function tick(world as IWorld, data as IData)as IData{
        var d = data;
        if(world.remote)return d;
        if(ticking.length>0){
            for t in ticking{
                d = t(world,d);
                if(D.get(d,"removed").asBool())return d;
            }
        }
        if(renderRegistered){
            var p as double[]= V.readFromData(d);
            var c = D.get(d,"color").asInt();
            var r = D.get(d,"effectiveRadius").asDouble();
            NetworkHandler.sendToAllAround("FXGenerator_by_DoremySwee_id_"~name,
                p[0],p[1],p[2],r, world.getDimension(),
                function(buffer)as void{
                    buffer.writeData(d);
                }
            );
        }
        return d;
    }
    function regi()as FXGenerator{
        if(renderRegistered){
            NetworkHandler.registerServer2ClientMessage("FXGenerator_by_DoremySwee_id_"~name,
            function(player,buffer){
                var data=buffer.readData();
                renderClient(player,data);
            });
        }
        events.onWorldTick(function(event as crafttweaker.event.WorldTickEvent){
            var world = event.world;
            var dim = world.getDimension();
            if(event.phase!="START"||event.side!="SERVER")return;
            if(objects has dim){
                var t as [IData] = [] as [IData];
                for i,o in objects[dim]{
                    if(!o.memberGet("removed").asBool()){
                        t+=this.tick(world,o);
                    }
                }
                objects[dim]=t;
            }
        });
        return this;
    }
    var defaultData as IData= {
        "color":0xFFFFFF,
        "effectiveRadius":100.0,
        "x":0.0, "y":0.0, "z":0.0,
        "removed":false
    } as IData;
    function setDefaultData(d as IData)as FXGenerator{
        defaultData=d;
        return this;
    }
    function updateDefaultData(d as IData)as FXGenerator{
        defaultData=defaultData+d;
        return this;
    }
    function create(world as IWorld, data as IData){
        var dim = world.getDimension();
        var d as IData=defaultData+data;
        if(objects has dim){
            objects[dim] = objects[dim] + d;
        }
        else{
            objects[dim] = [d]as [IData];
        }
    }
    function copy(name as string)as FXGenerator{
        var result = FXGenerator(name).setDefaultData(defaultData);
        if(renderRegistered){
            result.setRender(renderClient);
        }
        for f in ticking{
            result.addTick(f);
        }
        return result;
    }
    function addAging(limit as int)as FXGenerator{
        updateDefaultData({"life":0,"lifeLimit":limit});
        addTick(function(world as IWorld, data as IData)as IData{
            var life = data.life.asInt()+1;
            return data + {
                "life":life,
                "removed":(life>data.lifeLimit.asInt())
            };
        });
        return this;
    }
}


//Abuse of this FXGenerator is not recommended. This may lead to huge lag and networking burdern
static SingleOrb as FXGenerator = FXGenerator("singleOrb")
    .updateDefaultData({
        "size":3.0, "colli":true,
        "lastX":0.0,"lastY":0.0,"lastZ":0.0,
        "effectiveRadius":300.0, "damage":9.0,
        "renderInterval":2,
        "renderTime":1,
        "particleLifeCoef":3.0
    })
    .addAging(200)
    .addTick(function(world as IWorld, data as IData)as IData{
        //This recording method takes place in the beginning of the game tick, before any movement.
        var p = V.readFromData(data);
        return data + V.asData(p,"last",true);
    })
    .addTick(function(world as IWorld, data as IData)as IData{
        var p = V.readFromData(data);
        var R = data.effectiveRadius.asDouble();
        var r = data.size.asDouble();
        var pl = world.getClosestPlayer(p[0],p[1],p[2],R,false);
        if(isNull(pl))return data+{"removed":true};
        if(!data.colli.asBool())return data;
        var diff = V.subtract(p, V.getPos(pl));
        if(V.dot(diff,diff)>r*r)return data;
        pl.attackEntityFrom(<damageSource:MAGIC>,data.damage);
        return data+{"removed":true};
    })
    .setRender(function(player as IPlayer, data as IData)as void{
        if(data.life.asInt() % data.renderInterval.asInt() != 0 && data.life.asInt()>3 )return;
        for i in 0 to data.renderTime.asInt(){
            M.createFX(data+{
                "r":data.size,
                "a":data.particleLifeCoef.asDouble()*((data.renderInterval.asInt()<3)?data.renderInterval:3)
            });
        }
    })
    .regi();

static LinearOrb as FXGenerator = SingleOrb.copy("linearOrb")
    .addTick(function(world as IWorld, data as IData)as IData{
        var p = V.readFromData(data);
        var v = V.readFromData(data,"v");
        var p1 = V.add(p,v);
        return data + V.asData(p1,"v");
    })
    .updateDefaultData({
        "renderInterval":6,
        "vx":0.0,"vy":0.0,"vz":0.0,
    })
    .regi();

static segment as FXGenerator = FXGenerator("segment")
    .updateDefaultData({
        "renderInterval":6,
        "size":3.0, "colli":true,
        "effectiveRadius":600.0, "damage":9.0,
        "renderTime":1, "renderNum": 10,
        "Ax":0.0,"Ay":0.0,"Az":0.0,
        "Bx":0.0,"By":0.0,"Bz":0.0,
        "ALx":0.0,"ALy":0.0,"ALz":0.0,
        "BLx":0.0,"BLy":0.0,"BLz":0.0,
        "particleLifeCoef":2.0
    })
    .addAging(200)
    .addTick(function(world as IWorld, data as IData)as IData{
        var A = V.readFromData(data,"A");
        var B = V.readFromData(data,"B");
        var p = V.scale(V.add(A,B),0.5);
        return data + V.asData(A,"AL") + V.asData(B,"BL") + V.asData(p);
    })
    .addTick(function(world as IWorld, data as IData)as IData{
        var A = V.readFromData(data,"A");
        var B = V.readFromData(data,"B");
        var flag = false;
        for player in world.getAllPlayers(){
            var r = V.pointSegmentDist(V.getPos(player),A,B);
            flag = flag || (r<data.effectiveRadius.asDouble());
            if(r<data.size.asDouble() && data.colli.asBool())player.attackEntityFrom(<damageSource:MAGIC>,data.damage);
        }
        return data + {"removed":!flag};
    })
    .setRender(function(player as IPlayer, data as IData)as void{
        if(data.life.asInt() % data.renderInterval.asInt() != 0 && data.life.asInt()>3 )return;
        var n = data.renderNum.asInt();
        for i in 0 to n+1{
            var AL = V.readFromData(data,"AL");
            var BL = V.readFromData(data,"BL");
            var A = V.readFromData(data,"A");
            var B = V.readFromData(data,"B");
            
            var ratio = 1.0/n*i;
            for j in 0 to 2{
                if(ratio>1 || ratio<0) continue;
                var p = V.combine(A,B,ratio);
                var po = V.combine(AL,BL,ratio);
                var v = V.subtract(p,po);
                for k in 0 to data.renderTime.asInt(){
                    M.createFX(data+V.asData(p)+V.asData(v,"v")+{
                        "r":data.size,
                        "a":data.particleLifeCoef.asDouble()*((data.renderInterval.asInt()<3)?data.renderInterval:3)
                    });
                }
                var F = V.getFootPoint(V.getPos(player),A,B);
                ratio = V.divide(V.subtract(F,A),V.subtract(B,A)) + 0.1 * i/n - 0.05;
            }
        }
    })
    .regi();

static segmentMoving as FXGenerator = segment.copy("segmentMoving")
    .addTick(function(world as IWorld, data as IData)as IData{
        var vA = V.readFromData(data,"vA");
        var vB = V.readFromData(data,"vB");
        //print("T");
        //print(V.display(vA));
        //print(V.display(vB));
        var pA = V.add(V.readFromData(data,"A"),vA);
        var pB = V.add(V.readFromData(data,"B"),vB);
        //print(V.display(pA));
        //print(V.display(pB));
        return data + V.asData(pA,"A") + V.asData(pB,"B");
    })
    .updateDefaultData({
        "vAx":0.0,"vAy":0.0,"vAz":0.0,
        "vBx":0.0,"vBy":0.0,"vBz":0.0
    })
    .regi();
/*
static arc as FXGenerator = FXGenerator("arc")
    .addAging(300)
    .updateDefaultData({
        "lastX":0.0,"lastY":0.0,"lastZ":0.0,
        "axisAx":0.0,"axisAy":0.0,"axisAz":0.0,
        "axisBx":0.0,"axisBy":0.0,"axisBz":0.0,
        "angleA":0.0,"angleB":360.0,"radius":0.0,
        "renderNum":20, "renderTime":1, "size":3.0,
        "renderInterval":6, "particleLifeCoef":2.0
    })
    .addTick(function(world as IWorld, data as IData)as IData{
        var p = V.readFromData(data);
        return data + V.asData(p,"last",true);
    })
    .addTick(function(world as IWorld, data as IData)as IData{
        var p0 = V.readFromData(data);
        var diffMin = V.subtract(p0,V.getPos(world.getClosestPlayer(p[0],p[1],p[2],R,false)));
        var temp0 = data.radius.asDouble()+data.size.asDouble();
        if(V.dot(diffMin,diffMin)>temp0*temp0) return;
        var temp1 = data.radius.asDouble()-data.size.asDouble();
        var a = V.readFromData(data,"axisA");
        var b = V.readFromData(data,"axisB");
        for player in world.getAllPlayers(){
            var diff = V.subtract(p0,V.getPos(world.getClosestPlayer(p[0],p[1],p[2],R,false)));
            if(V.dot(diff,diff)>temp0*temp0) continue;
            if(V.dot(diff,diff)<temp1*temp1) continue;
            var pr0 = V.prject()
        }
    })
    .setRender(function(player as IPlayer, data as IData)as void{
    })
    .regi();*/
events.onItemToss(function(event as crafttweaker.event.ItemTossEvent){
     var H = V.STAR_A;
    var player = event.player;
    var world = player.world;
    
    for side in H.sides{
        /*for i in 0 to 40{
            var ratio = 1.0/41*(i+1);
            var p = V.combine(H.vertexes[side[0]],H.vertexes[side[1]],ratio);
            SingleOrb.create(world,{
                "color":0x7777FF,
                "size":0.3,
                "colli":false
            }+V.asData(V.add(V.getPos(player),V.scale(p,3))));
        }*/
        segmentMoving.create(world,{
            "color":0x077777,
            "size":0.3,
            "colli":false,
            "renderNum":3,
            "renderInterval":9,
            "lifeLimit":200,
            "type":"chaosProjectile",
            "textureIndex":0
        }+V.asData(V.scale(H.vertexes[side[0]],0.02),"vA")
        +V.asData(V.scale(H.vertexes[side[1]],0.02),"vB")
        +V.asData(V.getPos(player),"A")+V.asData(V.getPos(player),"B"));
    }/*
    for p in H.vertexes{
        SingleOrb.create(world,{
            "color":0x7777FF,
            "size":0.9,
            "colli":false,
            "renderTime":3
        }+V.asData(V.add(V.getPos(player),V.scale(p,7))));
    }*
    M.createBotSparkle({
        "color":0x7777FF,
        "r":0.3
    }+V.asData(V.getPos(player)));*/
});