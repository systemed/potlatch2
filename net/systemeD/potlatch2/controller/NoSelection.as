package net.systemeD.potlatch2.controller {
	import flash.events.*;
	import flash.display.*;
	import net.systemeD.potlatch2.EditController;
	import net.systemeD.halcyon.connection.*;
    import net.systemeD.halcyon.connection.actions.*;
	import net.systemeD.halcyon.Map;
	import net.systemeD.halcyon.MapPaint;

	public class NoSelection extends ControllerState {

		public function NoSelection() {
		}

		override public function isSelectionState():Boolean {
			return false;
		}
		
		override public function processMouseEvent(event:MouseEvent, entity:Entity):ControllerState {
			var cs:ControllerState = sharedMouseEvents(event, entity);
			if (cs) return cs;

			var paint:MapPaint = getMapPaint(DisplayObject(event.target));
			var focus:Entity = getTopLevelFocusEntity(entity);

			if (event.type==MouseEvent.MOUSE_UP && (focus==null || (paint && paint.isBackground)) && map.dragstate!=map.DRAGGING && map.dragstate!=map.SWALLOW_MOUSEUP) {
				map.dragstate=map.NOT_DRAGGING;
				var conn:Connection = layer.connection;
				
				// User just created a node...
				var nodeAction:CreatePOIAction = new CreatePOIAction(
				    conn, 
				    {}, 
				    controller.map.coord2lat(event.localY), 
				    controller.map.coord2lon(event.localX));
				
				MainUndoStack.getGlobalStack().addAction(nodeAction);

				// And a way. See BeginWayAction doco for why we keep these separate.
				var wayAction:BeginWayAction = new BeginWayAction(
				    layer.connection,
				    nodeAction.getNode());

                MainUndoStack.getGlobalStack().addAction(wayAction);
				
				return new DrawWay(wayAction.getWay(), true, false);
			}
			return this;
		}
		
		override public function processKeyboardEvent(event:KeyboardEvent):ControllerState {
			var cs:ControllerState = sharedKeyboardEvents(event);
			return cs ? cs : this;
		}
		
        override public function enterState():void {
			controller.map.mouseUpHandler();
        }
        override public function exitState(newState:ControllerState):void {
        }
		override public function toString():String {
			return "NoSelection";
		}

	}
}
