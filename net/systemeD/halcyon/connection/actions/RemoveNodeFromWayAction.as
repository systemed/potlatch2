package net.systemeD.halcyon.connection.actions {

    import net.systemeD.halcyon.connection.*;
    
    public class RemoveNodeFromWayAction extends UndoableEntityAction {
    
        private var way:Way;          // synonym for entity
        private var nodeList:Array;   // points to raw node list of the way, to actually remove nodes
        private var index:int;       // index of the node we were asked to remove, or -1
        private var node:Node;        // the node we were asked to remove
        private var nodeRemovedFrom:Array;  // list of [node, index] pairs of nodes removed
        private var fireEvent:Boolean;      // should we send a signal?
        private var effects:CompositeUndoableAction; // possible side effects if we need to kill the way itself
        private var allowSingleNodeWays:Boolean; 
    
        /** Remove a node from a way. Specify either the node itself (all instances removed) or its index. 
        * For (unverified) historical reasons it also removes any repeated nodes first.
        * If removing this node leaves a 1-length way behind, the way is destroyed, if allowSingleNodeWays is false.
        * (Sometimes, like when drawing a way, a single-node way is ok.)
        * */
        public function RemoveNodeFromWayAction(way:Way, nodeList:Array, node:Node = null, index:int = -1, fireEvent:Boolean=true, allowSingleNodeWays:Boolean=false) {
            if (node == null)
                node = nodeList[index];
            super(way, "Remove node " + node.id + " from position " + index);
            
            if (node != null && index != -1 && nodeList[index] != node) {
                throw new Error("Node and index specified but inconsistent: nodes[" + index + "] = " + nodeList[index].id + "; node.id = " + node.id);
            }
            
            this.way = way;
            this.nodeList = nodeList;
            this.index = index;
            this.node = node;
            this.fireEvent = fireEvent;
            this.allowSingleNodeWays = allowSingleNodeWays;
        }
        
        public override function doAction():uint {

            function removeByIndex(idx: int):void {
                var removedNode:Node=nodeList.splice(idx, 1)[0];
                nodeRemovedFrom.push([removedNode, idx]);
                if (nodeList.indexOf(removedNode) == -1) { removedNode.removeParent(way); }
                if (fireEvent) {
                   entity.dispatchEvent(new WayNodeEvent(Connection.WAY_NODE_REMOVED, removedNode, way, idx));
                }
                
            }
            if (nodeList.indexOf(node) < 0)
                return NO_CHANGE;

            way.suspend();
                
            nodeRemovedFrom = [];
            var adjustedindex:int = index;
            
            // first, remove any repeated nodes, adjusting an offset as necessary.
            // Ideally, we'd use way.removeRepeatedNodes(), but the undo action model kind of prevents that.
            for (var i:int = 1; i < nodeList.length; i++) {
                if (nodeList[i] == nodeList[i-1] && i != (adjustedindex)) {
                    removeByIndex(i);
                    
                    if (adjustedindex > i) // we deleted an item to the left of the node we're going to remove
                        adjustedindex --;
                }
            }
            
            if (index > -1) { // handle "remove by index" case
                removeByIndex(adjustedindex);
                if (index > 0 && adjustedindex < nodeList.length && nodeList[adjustedindex - 1] == nodeList[adjustedindex]) {
                    // removing a node created repeated nodes ( ABCBD minus C = ABBD, make it ABD)
                    removeByIndex(adjustedindex);
                } 
            } else { // handle "remove all instances of node" case
                for (i = 0; i < nodeList.length; i++) {
                    if (nodeList[i] == node) {
                        removeByIndex(i);
                        if (i > 0 && i < nodeList.length && nodeList[i - 1] == nodeList[i]) {
                            // same test as above
                            removeByIndex(i);
                        } 
                    }
                }
            }
            
            if (nodeList.length == 0)
                way.deleted = true;
            
            if (nodeList.length == 1 && !allowSingleNodeWays) {
            	way.deleted = true;
                // And if it's length 1, also do something about the remaining node.
                var orphan:Node = nodeList[0]; 
                removeByIndex(0); // (Length zero now.)
                // this code duplicated from DeleteWayAction.
                if (!orphan.hasParents && !orphan.hasInterestingTags()) {
                    // the last node wasn't interesting after all, so destroy it.
                    effects = new CompositeUndoableAction("Way deletion side effects.");
                    orphan.remove(effects.push);
                    effects.doAction();
                } else {
                    if (!orphan.hasParentWays) 
                        orphan.connection.registerPOI(node); // it's now a POI
                    // or it's already part of another way.
                }
                way.dispatchEvent(new EntityEvent(Connection.WAY_DELETED, way));    // delete WayUI

            }
            markDirty();
            way.resume();
            
            return SUCCESS;
        }

        public override function undoAction():uint {
            node.addParent(entity);
            
            // re-add the node(s) that was/were removed earlier, in the correct sequence, and to the right index.
            while (nodeRemovedFrom.length > 0) {
                var node_index:Array = nodeRemovedFrom.pop();
                var reinstate:Node = node_index[0];
                var idx:int = node_index[1];
                nodeList.splice(idx, 0, reinstate);
                reinstate.addParent(way);
                if (fireEvent) {
                    entity.dispatchEvent(new WayNodeEvent(Connection.WAY_NODE_ADDED, reinstate, Way(entity), idx));
                }
            }
            if (effects) effects.undoAction();
            
            // not sure what to do if we restore a 1-length way. Hrm.
            if (way.deleted && nodeList.length > 1) {
            	way.deleted = false;
            	way.connection.dispatchEvent(new EntityEvent(Connection.NEW_WAY, way));
            	// for symmetry, we ought to register node UIs here, but seems to perform correctly as is.
            }
            markClean();
            
            return SUCCESS;
        }
   }
}

