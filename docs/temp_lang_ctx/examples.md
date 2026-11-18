# Examples

Updated: 2026-11-16. Nothing here has been parsed or run. E-1 to E-3 were sketches in the old two-file syntax; their files are deleted.

## E-4 The fourteen-file set

- Purpose: show the whole syntax in the smallest set of files.
- Files: `examples/shared.vega`, `Hero.vega`, `ProductInfo.vega`, `BuyButton.vega`, `ProductCard.vega`, `Shell.vega`, `ProductMeta.vega`, `SiteMeta.vega`, `Tabs.vega`, `TabPanel.vega`, `Grid.vega`, `Recipe.vega`, `RecipeCard.vega`, `FeaturedRecipe.vega`.
- Status: sketch. Decisions it follows: D-13 to D-65 in `decisions.md`.
- It shows, once each: a comment in a block and inline (D-39), a `std.Url` field (D-41), a `std.RichText` value output as HTML (D-37), a loader that may find nothing (D-38), the three prop forms (D-51), `fields { }` and `props { }` blocks (D-59), and a code-only component called with `render`.
- Added 2026-11-17: the split form, with `SiteMeta` defined in `shared.vega` and its template in `SiteMeta.vega` (D-16, D-61); default content for the `head` slot (D-31); a `List` field (D-50); `Bool`, `elif` and `for item, i in list`, which have no decision entry yet.
- Added 2026-11-18: a parent that loops over a slot's children (D-62). `Tabs.vega` reads a child's field and outputs each child in a wrapper; `Grid.vega` counts the children and hides its wrapper when the slot is empty. Both use `$id` (D-65); `Tabs.vega` builds each wrapper's id from `$id` and the position.
- Added 2026-11-18: a content type, `Recipe` (D-63), and `RecipeCard.vega`, a code-only component that takes a `Recipe` as a prop. `FeaturedRecipe.vega` has a `Recipe` picker field and renders `RecipeCard` with the pick. How a component loads a list of recipes is not decided, so no example does.
- Not decided, so the examples do not depend on it: whether `i` starts at 0 or 1.
- Library names it invents: `shopify.pageBy`, `shopify.Page`, `product.description`, `$shopify.product`, `shopify.recommendations`, `product.url`, `product.price`, `product.compareAtPrice`, `site.name`, `site.shareImage`.

## E-5 Three mistakes and the error for each

- Purpose: PoC criterion 2, "a type error shows the correct file, line and field".
- Status: sketch. The wording and layout of the messages are proposed, not decided.

### E-5a A value that can be null is output without a fallback

Change `examples/BuyButton.vega` line 28 from `{{text ?? t("product.add_to_cart")}}` to `{{text}}`.

```
error: `text` can be null
  BuyButton.vega:28:7     {{text}}
  field: BuyButton.text is `Text { max = 30 }?`, declared at BuyButton.vega:6
  fix: give a fallback, `text ?? "..."`, or wrap it in `{{if text != null}}`
```

### E-5b A field name is misspelled

Change `examples/BuyButton.vega` line 21 from `{{variant.title}}` to `{{variant.titel}}`.

```
error: `shopify.Variant` has no field `titel`
  BuyButton.vega:21:11    {{variant.titel}}
  `variant` comes from `product.variants`, a `List { of = shopify.Variant }`
  did you mean `title`?
```

### E-5c A parent forgets to pass a value its slot children need

Change `examples/ProductInfo.vega` line 36 from `{{slot blocks { product = product } }}` to `{{slot blocks}}`.

```
error: slot `blocks` does not pass `product`
  ProductInfo.vega:36:23  {{slot blocks}}
  needed by: the prop `product` of BuyButton, declared `shopify.Product` at BuyButton.vega:9
  `BuyButton` is allowed in this slot through `Blocks` (shared.vega:5)
  fix: `{{slot blocks { product = ... } }}`
```

## E-6 The buy button in Liquid and in `.vega`

- Purpose: the PoC question, "is this meaningfully better than Liquid?".
- Status: sketch. The Liquid is written from memory of Shopify theme conventions and has not been run on a store.

### Liquid: block markup inside the section file, schema at the bottom of that file

```liquid
<form class="buy" method="post" action="/cart/add">
  <label>
    {{ 'product.option' | t }}
    <select name="id">
      {% for variant in product.variants %}
        <option value="{{ variant.id }}" {% unless variant.available %}disabled{% endunless %}>
          {{ variant.title }} ({{ variant.price | money }})
        </option>
      {% endfor %}
    </select>
  </label>
  <button type="submit" {% unless product.available %}disabled{% endunless %}>
    {% if product.available %}
      {% if block.settings.label != blank %}{{ block.settings.label }}{% else %}{{ 'product.add_to_cart' | t }}{% endif %}
    {% else %}
      {{ 'product.sold_out' | t }}
    {% endif %}
  </button>
</form>

{% schema %}
{
  "name": "Product information",
  "blocks": [
    {
      "type": "buy_button",
      "name": "Buy button",
      "settings": [{ "type": "text", "id": "label", "label": "Button text" }]
    }
  ]
}
{% endschema %}
```

### `.vega`: `examples/BuyButton.vega`

```
{{
  use shopify

  BuyButton :: component {
    fields {
      text: Text { max = 30 }? @{ label = "Button text" }
    }
    props {
      product: shopify.Product
    }
  }

  template BuyButton
}}
<form class="buy" method="post" action="/cart/add">
  <label>
    {{t("product.option")}}
    <select name="id">
      {{for variant in product.variants}}
        <option value="{{variant.id}}" {{if not variant.available}}disabled{{/if}}>
          {{variant.title}} ({{variant.price | shopify.money}})
        </option>
      {{/for}}
    </select>
  </label>
  <button type="submit" {{if not product.available}}disabled{{/if}}>
    {{if product.available}}
      {{text ?? t("product.add_to_cart")}}
    {{else}}
      {{t("product.sold_out")}}
    {{/if}}
  </button>
</form>
```

### What differs

| Point | Liquid | `.vega` |
| --- | --- | --- |
| Where `product` comes from | An ambient object. The file does not say it needs one | `product: shopify.Product`, a prop. A parent must pass it (E-5c) |
| A misspelled field, `variant.titel` | Renders an empty string. No error | Error before rendering (E-5b) |
| An empty optional setting | A runtime test, `!= blank`, that is easy to forget | Must be handled, or the file does not pass the check (E-5a) |
| The editor field | A JSON entry in another part of the section file, read as `block.settings.label` | One typed line, read as `text` |
| A length limit on the field | Not checked here | `Text { max = 30 }` |
| Where `money` comes from | A global filter | `shopify.money`, named by `use shopify` |
| Reuse in another section | The block is declared inside each section's schema | One component, listed in the `Blocks` union |

The two templates are about the same length. The gain is in what is checked before a page renders, not in fewer characters.
