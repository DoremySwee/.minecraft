#loader contenttweaker
import mods.contenttweaker.VanillaFactory;
import mods.randomtweaker.cote.ISubTileEntityGenerating;
val flower as ISubTileEntityGenerating = VanillaFactory.createSubTileGenerating("irisotos");
flower.range = 1;
flower.maxMana = 10000000;
flower.register();