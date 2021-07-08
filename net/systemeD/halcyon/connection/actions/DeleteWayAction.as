package net.systemeD.halcyon.connection.actions {

    import net.systemeD.halcyon.connection.*;
    
    public class DeleteWayAction extends UndoableEntityAction {
        private var setDeleted:Function;
        private var effects:CompositeUndoableAction;
        private var nodeList:Array;
        private var oldNodeList:Array;
        
        public function DeleteWayAction(way:Way, setDeleted:Function, nodeList:Array) {
            super(way, "Delete");
            this.setDeleted = setDeleted;
            this.nodeList = nodeList; // reference to way's actual nodes array. 
        }
            
        public override function doAction():uint {
            var way:Way = entity as Way;
            if ( way.isDeleted() )
                return NO_CHANGE;

            effects = new CompositeUndoableAction("Delete refs");            
			var node:Node;
			way.suspend();
			way.removeFromParents(effects.push);
			oldNodeList = nodeList.slice();
			// Delete or detach each node
			while (nodeList.length > 0) {
				
				node=nodeList.pop(); // do the actual deletion
				node.removeParent(way);
				way.dispatchEvent(new WayNodeEvent(Connection.WAY_NODE_REMOVED, node, way, 0));
                if (!node.hasParents && !node.hasInterestingTags()) { //need to trigger redraw of new POIs?
                  node.remove(effects.push);
                } else {
                  if (!node.hasParentWays) node.connection.registerPOI(node);
                }
			}
			effects.doAction();
			setDeleted(true);
            
            // see note in DeleteNodeAction
            if (way.id < 0) {
              markClean();
            } else {
              markDirty();
            }
			way.dispatchEvent(new EntityEvent(Connection.WAY_DELETED, way));	// delete WayUI
			way.resume();

            return SUCCESS;
        }
            
        public override function undoAction():uint {
            var way:Way = entity as Way;
			way.suspend();
            setDeleted(false);
            if (way.id < 0) {
              markDirty();
            } else {
              markClean();
            }
            entity.connection.dispatchEvent(new EntityEvent(Connection.NEW_WAY, way));
            if (effects) effects.undoAction();
            for each(var node:Node in oldNodeList) {
                nodeList.push(node);
            	node.addParent(way);
            	node.connection.unregisterPOI(node);
                way.dispatchEvent(new WayNodeEvent(Connection.WAY_NODE_ADDED, node, way, 0));
            }
			way.resume();
            return SUCCESS;
        }
    }
}

