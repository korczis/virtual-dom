module VirtualDom exposing
  ( Node
  , text, node, nodeNS
  , Property, property, attribute, attributeNS, mapProperty
  , style
  , on, onCustom
  , map
  , lazy, lazy2, lazy3
  , keyedNode, keyedNodeNS
  , program, programWithFlags
  )

{-| API to the core diffing algorithm. Can serve as a foundation for libraries
that expose more helper functions for HTML or SVG.

# Create
@docs Node, text, node, nodeNS

# Declare Properties and Attributes
@docs Property, property, attribute, attributeNS, mapProperty

# Styles
@docs style

# Events
@docs on, onCustom

# Routing Messages
@docs map

# Optimizations
@docs lazy, lazy2, lazy3, keyedNode, keyedNodeNS

# Programs
@docs program, programWithFlags

-}

import Elm.Kernel.VirtualDom
import Json.Decode as Json
import VirtualDom.Debug as Debug


{-| An immutable chunk of data representing a DOM node. This can be HTML or SVG.
-}
type Node msg = Node


{-| Create a DOM node with a tag name, a list of HTML properties that can
include styles and event listeners, a list of CSS properties like `color`, and
a list of child nodes.

    import Json.Encode as Json

    hello : Node msg
    hello =
      node "div" [] [ text "Hello!" ]

    greeting : Node msg
    greeting =
      node "div"
        [ property "id" (Json.string "greeting") ]
        [ text "Hello!" ]
-}
node : String -> List (Property msg) -> List (Node msg) -> Node msg
node =
  Elm.Kernel.VirtualDom.node


{-| Create a namespaced DOM node. For example, an SVG `<path>` node could be
defined like this:

    path : List (Property msg) -> List (Node msg) -> Node msg
    path attrubutes children =
      nodeNS "http://www.w3.org/2000/svg" "path" attributes children
-}
nodeNS : String -> String -> List (Property msg) -> List (Node msg) -> Node msg
nodeNS =
  Elm.Kernel.VirtualDom.nodeNS


{-| Just put plain text in the DOM. It will escape the string so that it appears
exactly as you specify.

    text "Hello World!"
-}
text : String -> Node msg
text =
  Elm.Kernel.VirtualDom.text


{-| This function is useful when nesting components with [the Elm
Architecture](https://github.com/evancz/elm-architecture-tutorial/). It lets
you transform the messages produced by a subtree.

Say you have a node named `button` that produces `()` values when it is
clicked. To get your model updating properly, you will probably want to tag
this `()` value like this:

    type Msg = Click | ...

    update msg model =
      case msg of
        Click ->
          ...

    view model =
      map (\_ -> Click) button

So now all the events produced by `button` will be transformed to be of type
`Msg` so they can be handled by your update function!
-}
map : (a -> msg) -> Node a -> Node msg
map =
  Elm.Kernel.VirtualDom.map



-- PROPERTIES


{-| When using HTML and JS, there are two ways to specify parts of a DOM node.

  1. Attributes &mdash; You can set things in HTML itself. So the `class`
     in `<div class="greeting"></div>` is called an *attribute*.

  2. Properties &mdash; You can also set things in JS. So the `className`
     in `div.className = 'greeting'` is called a *property*.

So the `class` attribute corresponds to the `className` property. At first
glance, perhaps this distinction is defensible, but it gets much crazier.
*There is not always a one-to-one mapping between attributes and properties!*
Yes, that is a true fact. Sometimes an attribute exists, but there is no
corresponding property. Sometimes changing an attribute does not change the
underlying property. For example, as of this writing, the `webkit-playsinline`
attribute can be used in HTML, but there is no corresponding property!
-}
type Property msg = Property


{-| Create arbitrary *properties*.

    import JavaScript.Encode as Json

    greeting : Html
    greeting =
        node "div" [ property "className" (Json.string "greeting") ] [
          text "Hello!"
        ]

Notice that you must give the *property* name, so we use `className` as it
would be in JavaScript, not `class` as it would appear in HTML.
-}
property : String -> Json.Value -> Property msg
property =
  Elm.Kernel.VirtualDom.property


{-| Create arbitrary HTML *attributes*. Maps onto JavaScript’s `setAttribute`
function under the hood.

    greeting : Html
    greeting =
        node "div" [ attribute "class" "greeting" ] [
          text "Hello!"
        ]

Notice that you must give the *attribute* name, so we use `class` as it would
be in HTML, not `className` as it would appear in JS.
-}
attribute : String -> String -> Property msg
attribute =
  Elm.Kernel.VirtualDom.attribute


{-| Would you believe that there is another way to do this?! This corresponds
to JavaScript's `setAttributeNS` function under the hood. It is doing pretty
much the same thing as `attribute` but you are able to have "namespaced"
attributes. As an example, the `elm-lang/svg` package defines an attribute
like this:

    xlinkHref : String -> Attribute msg
    xlinkHref =
      attributeNS "http://www.w3.org/1999/xlink" "xlink:href"
-}
attributeNS : String -> String -> String -> Property msg
attributeNS =
  Elm.Kernel.VirtualDom.attributeNS


{-| Transform the messages produced by a `Property`.
-}
mapProperty : (a -> b) -> Property a -> Property b
mapProperty =
  Elm.Kernel.VirtualDom.mapProperty


{-| Specify a style.

    greeting : Node msg
    greeting =
      node "div"
        [ style "backgroundColor" "red"
        , style "height" "90px"
        , style "width" "100%"
        ]
        [ text "Hello!"
        ]

-}
style : String -> String -> Property msg
style =
  Elm.Kernel.VirtualDom.style



-- EVENTS


{-| Create a custom event listener.

    import Json.Decode as Decode

    onClick : msg -> Property msg
    onClick msg =
      on "click" (Decode.succeed msg)

You first specify the name of the event in the same format as with JavaScript’s
`addEventListener`. Next you give a JSON decoder, which lets you pull
information out of the event object. If the decoder succeeds, it will produce
a message and route it to your `update` function.
-}
on : String -> Json.Decoder msg -> Property msg
on eventName decoder =
  onCustom eventName (Json.map toDefaultEvent decoder)


{-| Same as `on` but you can customize how the JavaScript event behaves. For example,
maybe when someone presses the ENTER key, you want to avoid a page scroll. You have
control over this with:

  - `stopPropagation = True` means the event stops traveling through the DOM. So if
  propagation of a click is stopped, it will not trigger any other event listeners.
  - `preventDefault = True` means any built-in browser behavior related to the event
  is prevented. This is handy with certain key presses or touch gestures.

-}
onCustom : String -> Json.Decoder { message : msg, stopPropagation : Bool, preventDefault : Bool } -> Property msg
onCustom =
  Elm.Kernel.VirtualDom.on


toDefaultEvent : msg -> { message : msg, stopPropagation : Bool, preventDefault : Bool }
toDefaultEvent message =
  { message = message
  , stopPropagation = False
  , preventDefault = False
  }



-- OPTIMIZATION


{-| A performance optimization that delays the building of virtual DOM nodes.

Calling `(view model)` will definitely build some virtual DOM, perhaps a lot of
it. Calling `(lazy view model)` delays the call until later. During diffing, we
can check to see if `model` is referentially equal to the previous value used,
and if so, we just stop. No need to build up the tree structure and diff it,
we know if the input to `view` is the same, the output must be the same!
-}
lazy : (a -> Node msg) -> a -> Node msg
lazy =
  Elm.Kernel.VirtualDom.lazy


{-| Same as `lazy` but checks on two arguments.
-}
lazy2 : (a -> b -> Node msg) -> a -> b -> Node msg
lazy2 =
  Elm.Kernel.VirtualDom.lazy2


{-| Same as `lazy` but checks on three arguments.
-}
lazy3 : (a -> b -> c -> Node msg) -> a -> b -> c -> Node msg
lazy3 =
  Elm.Kernel.VirtualDom.lazy3


{-| Works just like `node`, but you add a unique identifier to each child
node. You want this when you have a list of nodes that is changing: adding
nodes, removing nodes, etc. In these cases, the unique identifiers help make
the DOM modifications more efficient.
-}
keyedNode : String -> List (Property msg) -> List ( String, Node msg ) -> Node msg
keyedNode =
  Elm.Kernel.VirtualDom.keyedNode


{-| Create a keyed and namespaced DOM node. For example, an SVG `<g>` node
could be defined like this:

    g : List (Property msg) -> List ( String, Node msg ) -> Node msg
    g =
      keyedNodeNS "http://www.w3.org/2000/svg" "g"
-}
keyedNodeNS : String -> String -> List (Property msg) -> List ( String, Node msg ) -> Node msg
keyedNodeNS =
  Elm.Kernel.VirtualDom.keyedNodeNS



-- PROGRAMS


{-| Check out the docs for [`Html.App.program`][prog].
It works exactly the same way.

[prog]: http://package.elm-lang.org/packages/elm-lang/html/latest/Html-App#program
-}
program
  : { init : (model, Cmd msg)
    , update : msg -> model -> (model, Cmd msg)
    , subscriptions : model -> Sub msg
    , view : model -> Node msg
    }
  -> Program Never model msg
program impl =
  Elm.Kernel.VirtualDom.program Debug.wrap impl


{-| Check out the docs for [`Html.App.programWithFlags`][prog].
It works exactly the same way.

[prog]: http://package.elm-lang.org/packages/elm-lang/html/latest/Html-App#programWithFlags
-}
programWithFlags
  : { init : flags -> (model, Cmd msg)
    , update : msg -> model -> (model, Cmd msg)
    , subscriptions : model -> Sub msg
    , view : model -> Node msg
    }
  -> Program flags model msg
programWithFlags impl =
  Elm.Kernel.VirtualDom.programWithFlags Debug.wrapWithFlags impl

