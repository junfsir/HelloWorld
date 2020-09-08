Can you try with this patch applied to your `ClusterRole` definition `nginx-ingress-clusterrole`:

```yaml
@@ -157,7 +160,7 @@ rules:
       - list
       - watch
   - apiGroups:
-      - "extensions"
+      - "networking.k8s.io"
     resources:
       - ingresses
     verbs:
```

