package lz.native3d.materials;
import hxsl.Shader;

/**
 * ...
 * @author lizhi http://matrix3d.github.io/
 */
class PhongShader extends Shader
{
	static var SRC = { 
		var input: {
			xyz:Float3,
			normal:Float3,
			weight:Float3,
			matrixIndex:Float4,
			uv:Float2
		}
		
		//interpolated
		var eyespacePos:Float3;
		var surfaceNormal:Float3;
		var viewVec:Float3;
		var uv:Float2;
		var shadowDepthZW:Float2;
		
		//vertex parameter
		var modelViewMatrix:M44;
		var projectionMatrix:M44;
		var anmMats:M34<39>;
		var hasAnm:Bool;
		
		//fragment parameter
		var	ambient:Float3;
		var	diffuse:Float3;
		var	specular:Float4;
		var lights:Param < {
			var ambientLights:Array<{color:Float3}>;
			var distantLights:Array<{color:Float3,position:Float3}>;
			var pointLights:Array<{colorLen:Float4,position:Float3}>;
			var spotLights:Array<{colorLen:Float4,position:Float3,direction:Float3,innerOuter:Float2}>;
		}>;
		
		var diffuseMap:Texture;
		var hasDiffuseMap:Bool;
		
		var isShadowDepth:Bool;
		
		function vertex() {
			var wpos:Float4 = input.xyz.xyzw;
			if (hasAnm != null) {
				wpos.xyz = 
					wpos * input.weight.x * anmMats[input.matrixIndex.x ] 
					+ wpos * input.weight.y * anmMats[input.matrixIndex.y] 
					+ wpos * input.weight.z * anmMats[input.matrixIndex.z];
			}
			if (!isShadowDepth) {
				out = wpos * modelViewMatrix * projectionMatrix;
			}else{
				wpos = wpos * modelViewMatrix * projectionMatrix;
				shadowDepthZW = wpos.zw;
				out = wpos;
			}
			
			if(diffuse!=null||specular!=null){
				var eyespacePosTemp = (wpos.xyz * modelViewMatrix).xyz;
				eyespacePos = eyespacePosTemp;
				viewVec = normalize( -eyespacePosTemp);
				surfaceNormal = normalize(input.normal * modelViewMatrix);
			}
			if (hasDiffuseMap) {
				uv = input.uv;
			}
		}
		
		function fragment() {
			if(!isShadowDepth){
				var color:Float4 = [0,0,0,1.];
				for (light in lights.ambientLights) {
					color.xyz += ambient*diffuse.xyz*light.color;
				}
				for (light in lights.distantLights) {
					color.xyz += getPhongColor(light.position)
					*light.color;
				}
				for (light in lights.pointLights) {
					color.xyz += getPhongColor(light.position)
					*getDistanceColor(light.position,light.colorLen.w)
					*light.colorLen.xyz;
				}
				for (light in lights.spotLights) {
					color.xyz += getPhongColor(light.position)
					*getDistanceColor(light.position, light.colorLen.w)
					*getSmoothColor(light.position,light.direction,light.innerOuter.x,light.innerOuter.y)
					*light.colorLen.xyz;
				}
				if (hasDiffuseMap) {
					color *=diffuseMap.get(uv, wrap);
				}
				out =  color;
			}else {
				//pack
				var bitSh:Float4 = [0x1000000, 0x10000, 0x100, 1];
				var bitMsk:Float4 = [0, 1 / 0x100, 1 / 0x100, 1 / 0x100];
				var comp:Float4 = frc(shadowDepthZW.x/shadowDepthZW.y* bitSh);
				out = comp- comp.xxyz* bitMsk;
			}
		}
		
		function getPhongColor(position:Float3):Float3 {
			var lightVec:Float3 = normalize(position - eyespacePos);
			var color:Float3 = ambient;
			if (diffuse!=null) {
				color += diffuse.xyz * max(0, dot(lightVec, surfaceNormal));
			}
			if(specular!=null){
				var reflectedLightVec:Float3  = normalize(2* dot(lightVec, surfaceNormal)* surfaceNormal-lightVec);
				color += specular.xyz * pow(max(0, dot(reflectedLightVec, viewVec)), specular.w);
			}
			return color;
		}
		
		function getDistanceColor(position:Float3, lightDistance:Float):Float {
			var lightToPoint:Float3 = eyespacePos - position;
			return sat(1-dp3(lightToPoint,lightToPoint)/lightDistance/lightDistance);
		}
		function getSmoothColor(position:Float3, direction:Float3, inner:Float, outer:Float):Float {
			var factor1:Float = 1/ (cos(inner/2)- cos(outer/2));
			var factor2:Float = 1- cos(inner/2)* factor1;
			var lightToPoint:Float3 = eyespacePos - position;
			var lightAngleCosine:Float = dp3(direction, normalize(lightToPoint));
			return sat(factor1* lightAngleCosine+ factor2);
		}
	};
	public function new() 
	{
		super();
	}	
}