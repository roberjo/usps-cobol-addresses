# Tickets (ServiceNow stand-in)

Legacy batch work is mostly maintenance: an incident or request arrives, you
trace it through the libraries, make a small change, and promote it with a
change record. This folder is the paper trail for that loop.

- `INC<nnnnnnn>-<slug>.md`: incident. What failed and how it was diagnosed.
- `CHG<nnnnnnn>-<slug>.md`: change request. What will change, how it was tested, how to back out.

Start from [`INC-TEMPLATE.md`](INC-TEMPLATE.md) and [`CHG-TEMPLATE.md`](CHG-TEMPLATE.md).

## Change packages (ChangeMan stand-in)

- A package is a branch named for its change: `pkg/CHG0001234-fix-zip4-edit`.
- Promotion is `dev` → `test` → `prod`. Promote only when `make ci` is green, and
  when golden files change, the commit explains why.
- The CHG lists every component touched (programs, copybooks, JCL, control
  cards) and a backout plan.
