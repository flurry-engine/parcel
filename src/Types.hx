
import uk.aidanlee.flurry.api.resources.Resource.ShaderType;

typedef JsonResource = {
    var id : String;
    var path : String;
}

typedef JsonShaderValue = {
    var type : ShaderType;
    var name : String;
}

typedef JsonShaderBlock = {
    var name : String;
    var binding : Int;
    var values : Array<JsonShaderValue>;
}

typedef JsonShaderDefinition = {
    var textures : Array<String>;
    var blocks : Array<JsonShaderBlock>;
}

typedef JsonShaderSource = {
    var vertex : String;
    var fragment : String;
    var compiled : Bool;
}

typedef JsonShaderResource = JsonResource & {
    var ?ogl3 : JsonShaderSource;
    var ?ogl4 : JsonShaderSource;
    var ?hlsl : JsonShaderSource;
}

typedef JsonParcel = {
    var name : String;
    var assets : Array<String>;
    var depends : Array<String>;
}

typedef JsonAssets = {
    var bytes : Array<JsonResource>;
    var texts : Array<JsonResource>;
    var images : Array<JsonResource>;
    var sheets : Array<JsonResource>;
    var shaders : Array<JsonShaderResource>;
}

typedef JsonDefinition = {
    var assets : JsonAssets;
    var parcels : Array<JsonParcel>;
}
