#loader crafttweaker reloadableevents
#priority -1
recipes.removeByRecipeName("embers:ember_emmiter");
for i in 0 to 16{
    <entity:botania:doppleganger>.removeDrop(<botania:rune>.definition.makeStack(i));
}