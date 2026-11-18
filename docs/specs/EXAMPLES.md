---
status: draft
updated: 2026-11-18
---

# Examples

Nothing here has been parsed or run. Message wording and layout are proposed, not decided.

## E-4 The example set

Fifteen files in `examples/`, the smallest set that shows the whole syntax.

| File | Shows |
| --- | --- |
| `shared.vega` | Unions, an alias, a union of string literals, a component defined apart from its template, a `locale` table, a plugin component listed in a union |
| `Hero.vega` | Fields with limits, defaults and admin blocks; `show`; a `std.Url` field; a `List` field |
| `ProductInfo.vega` | The three prop forms; a slot with default content; a loader that may find nothing; a `std.RichText` value; `for item, i`; `render` |
| `BuyButton.vega` | A prop a parent must pass; `if` inside a start tag; `??` |
| `ProductCard.vega` | A code-only component; `elif` |
| `Shell.vega` | The shell with `head` and `body` slots; `std.asset` |
| `ProductMeta.vega`, `SiteMeta.vega` | Page metadata; nullable overrides; a `Bool` field; a template in its own file |
| `Tabs.vega`, `TabPanel.vega`, `Grid.vega` | A parent that loops over a slot's children; `$id` |
| `Recipe.vega`, `RecipeCard.vega`, `FeaturedRecipe.vega` | A content type, as a prop and as a picker field |
| `Map.vega` | A component that a plugin ships |

Names the examples invent: `shopify.pageBy`, `shopify.Page`, `shopify.recommendations`, `shopify.money`, `$shopify.product`, `std.siteSettings`, `std.take`, `std.join`, `std.length`, `std.empty`, `std.imageUrl`, and the fields of `shopify.Product`, `shopify.Variant` and `std.SiteSettings`.

## E-5 Three mistakes and the error for each

- Purpose: PoC criterion 2, "a type error shows the correct file, line and field".

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
  `BuyButton` is allowed in this slot through `Blocks` (shared.vega:7)
  fix: `{{slot blocks { product = ... } }}`
```

## E-6 The buy button in Liquid and in `.vega`

- Purpose: the PoC question, "is this meaningfully better than Liquid?".
- The Liquid is written from memory of Shopify theme conventions and has not been run on a store.

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
