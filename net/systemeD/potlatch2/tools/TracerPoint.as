package net.systemeD.potlatch2.tools {
	import net.systemeD.halcyon.TileSet;

	public class TracerPoint {

		public var x:Number;
		public var y:Number;
		
		private var l:Number;
		private var a:Number;
		private var b:Number;

		public var edge:Boolean;
		public var junction:Boolean;
		public var closed:Boolean;
		
		public function TracerPoint(x:Number,y:Number,edge:Boolean, c1:Number,c2:Number=NaN,c3:Number=NaN):void {
			this.x=x;
			this.y=y;
			this.edge=edge;
			closed=false; edge=false; junction=false;

			// Set LAB colour, converting from RGB if supplied as such
			if (isNaN(c2)) { var lab:Object=TracerPoint.lab(c1);
			                 l=lab.l; a=lab.a; b=lab.b; }
			          else { l=c1; a=c2; b=c3; }
		}
		
		public function difference(l2:Number, a2:Number, b2:Number):Number {
			return Math.pow(l-l2,2) + Math.pow(a-a2,2) + Math.pow(b-b2,2)
		}
		
		public static function lab(rgb:uint):Object {
			var r:Number = ((rgb>>16) & 0xFF)/255;
			var g:Number = ((rgb>>8 ) & 0xFF)/255;
			var b:Number = ( rgb      & 0xFF)/255;

			if (r > 0.04045) { r = Math.pow((r+0.055)/1.055, 2.4); } else { r = r/12.92; }
			if (g > 0.04045) { g = Math.pow((g+0.055)/1.055, 2.4); } else { g = g/12.92; }
			if (b > 0.04045) { b = Math.pow((b+0.055)/1.055, 2.4); } else { b = b/12.92; }
			r = r * 100; g = g * 100; b = b * 100;
 
			var x:Number = (r*0.4124 + g*0.3576 + b*0.1805) / 95.047;
			var y:Number = (r*0.2126 + g*0.7152 + b*0.0722) / 100;
			var z:Number = (r*0.0193 + g*0.1192 + b*0.9505) / 108.883;
 
			if ( x > 0.008856 ) { x = Math.pow(x,1/3); } else { x = (7.787*x) + (16/116); }
			if ( y > 0.008856 ) { y = Math.pow(y,1/3); } else { y = (7.787*y) + (16/116); }
			if ( z > 0.008856 ) { z = Math.pow(z,1/3); } else { z = (7.787*z) + (16/116); }
 
			return ({ l: (116*y)-16, a:500*(x-y), b: 200*(y-z) });
		}
		
		public function toString():String {
			return "("+x+","+y+(junction ? "J":"")+")";
		}

	}
}
