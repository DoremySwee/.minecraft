#priority 114514
import crafttweaker.mods.IMod;
import crafttweaker.mods.ILoadedMods;
import scripts.Lib;

mods.botania.Orechid.removeOre(<ore:oreCinnabar>);
mods.botania.Orechid.removeOre(<ore:oreUranium>);
mods.botania.Orechid.removeOre(<ore:oreAmber>);
val MA=loadedMods["mysticalagriculture"] as IMod;
for i in MA.items{
    if(i.definition.id.contains("reprocessor"))recipes.remove(i);
    if(i.definition.id.contains("storage"))recipes.remove(i);
    if(i.definition.id.contains("tinkering"))recipes.remove(i);
	if(i.definition.id.contains("crafting"))recipes.remove(i);
	if(i.definition.id.contains("crafting"))recipes.remove(i);	
	if(i.definition.id.contains("seeds"))recipes.remove(i);	
}