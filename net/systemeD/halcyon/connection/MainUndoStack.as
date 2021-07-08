package net.systemeD.halcyon.connection {

    import flash.events.*;


    /**
    * The main undo stack controls which actions can be undone or redone from the current situation.
    *
    * @see UndoableAction All actions inherit from undoable action
    */

    public class MainUndoStack extends EventDispatcher {
        private static const GLOBAL_INSTANCE:MainUndoStack = new MainUndoStack();
        
        public static function getGlobalStack():MainUndoStack {
            return GLOBAL_INSTANCE;
        }
        
        private var undoActions:Array = [];
        private var redoActions:Array = [];
        private var undorequests:int = 0;
        private var redorequests:int = 0;

        /**
         * Performs the action, then puts it on the undo stack.
         *
         * If you want to delay execution don't put it on this
         * stack -- find another one.
         */
        public function addAction(action:UndoableAction):void {
            var result:uint = action.doAction();
            
            switch ( result ) {
            
            case UndoableAction.FAIL:
                throw new Error("Failure performing "+action);
                
            case UndoableAction.NO_CHANGE:
                // nothing to do, and don't add to stack
                break;
                
            case UndoableAction.SUCCESS:
            default:
                if ( undoActions.length > 0 ) {
                    var previous:UndoableAction = undoActions[undoActions.length - 1];
                    var isMerged:Boolean = action.mergePrevious(previous);
                    if ( isMerged ) {
						UndoableEntityAction(action).wasDirty = UndoableEntityAction(previous).wasDirty;
						UndoableEntityAction(action).connectionWasDirty = UndoableEntityAction(previous).connectionWasDirty;
                        undoActions.pop();
					}
                }
                undoActions.push(action);
                redoActions = [];
                dispatchEvent(new Event("new_undo_item"));
                dispatchEvent(new Event("new_redo_item"));
                break;
                
            }
        }
        
        /**
         * Call to kill the undo and redo stacks -- the user will not be able to undo
         * anything they previously did after this is called.
         */
        public function breakUndo():void {
            undoActions = [];
            redoActions = [];
            dispatchEvent(new Event("new_undo_item"));
            dispatchEvent(new Event("new_redo_item"));
        }
        
        [Bindable(event="new_undo_item")]
        public function canUndo():Boolean {
            return undoActions.length > 0;
        }
        
        [Bindable(event="new_redo_item")]
        public function canRedo():Boolean {
            return redoActions.length > 0;
        }

        /**
        * Undo the most recent action, and add it to the top of the redo stack
        */
        public function undo():void {
			if (!undoActions.length) { return; }
            var action:UndoableAction = undoActions.pop();
            action.undoAction();
            redoActions.push(action);
            dispatchEvent(new Event("new_undo_item"));
            dispatchEvent(new Event("new_redo_item"));
            if (undorequests > 0) {
            	undorequests --;
            	undo();
            }
        }

        /**
        * Undo the most recent action, but only if it's a particular class
        * @param action The class of the previous action, for testing
        */
		public function undoIfAction(action:Class):Boolean {
			if (!undoActions.length) { return false; }
			if (undoActions[undoActions.length-1] is action) {
				undo();
				return true;
			} else {
				return false;
			}
		}
		
        /**
        * Remove (without undoing) the most recent action, but only if it's a particular class
        * @param action The class of the previous action.
        */
		public function removeLastIfAction(action:Class):UndoableAction {
			if (undoActions.length && undoActions[undoActions.length-1] is action) {
				return undoActions.pop() as UndoableAction;
			}
			return null;
		}

        [Bindable(event="new_undo_item")]
		public function getUndoDescription():String {
			if (undoActions.length==0) return null;
			if (undoActions[undoActions.length-1].name) return undoActions[undoActions.length-1].name;
			return null;
		}

        [Bindable(event="new_redo_item")]
		public function getRedoDescription():String {
			if (redoActions.length==0) return null;
			if (redoActions[redoActions.length-1].name) return redoActions[redoActions.length-1].name;
			return null;
		}

        /**
        * Takes the action most recently undone, does it, and adds it to the undo stack
        */
        public function redo():void {
			if (!redoActions.length) { return; }
            var action:UndoableAction = redoActions.pop();
            action.doAction();
            undoActions.push(action);
            dispatchEvent(new Event("new_undo_item"));
            dispatchEvent(new Event("new_redo_item"));
            if (redorequests > 0) {
                redorequests --;
                redo();
            }
            
        }
        
        /** The cleanest solution to an ugly problem. Say an undo event X wants to call
        * another undo event Y: if it calls it directly, they end up swapped
        * in the undo history. This way, they can get called in the normal order. It's
        * a way to loosely chain two events together. */ 
        public function requestUndo():void {
            undorequests = undorequests + 1;
        }

        public function requestRedo():void {
            redorequests = redorequests + 1;
        }
       
    }
}
