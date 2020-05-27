package src;

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
    var fonts : Array<JsonResource>;
    var images : Array<JsonResource>;
    var sheets : Array<JsonResource>;
    var shaders : Array<JsonShaderResource>;
}

typedef JsonDefinition = {
    var assets : JsonAssets;
    var parcels : Array<JsonParcel>;
}

typedef JsonFontChar = {
    var id : Int;
    var index : Int;
    var char : String;
    var width : Int;
    var height : Int;
    var xoffset : Int;
    var yoffset : Int;
    var xadvance : Int;
    var x : Int;
    var y : Int;
    var page : Int;
}

typedef JsonFontKerning = {
    var first : Int;
    var second : Int;
    var amount : Int;
}

typedef JsonFontInfo = {
    var face : String;
    var size : Int;
    var bold : Int;
    var italic : Int;
    var charset : Array<String>;
    var unicode : Int;
    var stretchH : Int;
    var smooth : Int;
    var aa : Int;
    var padding : Array<Int>;
    var spacing : Array<Int>;
}

typedef JsonFontCommon = {
    var lineHeight : Int;
    var base : Int;
    var scaleW : Int;
    var scaleH : Int;
    var pages : Int;
    var packed : Int;
    var alphaChnl : Int;
    var redChnl : Int;
    var greenChnl : Int;
    var blueChnl : Int;
}

typedef JsonFontDistanceField = {
    var fieldType : String;
    var distanceRange : Int;
}

typedef JsonFontDefinition = {
    var info : JsonFontInfo;
    var common : JsonFontCommon;
    var distanceField : JsonFontDistanceField;
    var pages : Array<String>;
    var chars : Array<JsonFontChar>;
    var kerning : Array<JsonFontKerning>;
}
